import url from 'url'
import path from 'path'
import readline from 'node:readline/promises'
import { produce } from 'immer'
import { execa } from 'execa'
import * as _ from 'lodash'
import { NixFlakeMetadata, NixTaskObject, Task } from './interfaces'
import { notEmpty } from './ts'
import chalk from 'chalk'
import { findUp } from 'find-up'
import fss from 'fs-extra'
import { nixEval, startNixRepl } from './nixRepl'

startNixRepl()

let getTasksNix = require(process.env.CONF_NIX_LIB_PATH + '/getTasks.nix')
getTasksNix = getTasksNix.substring(
  0,
  getTasksNix.lastIndexOf('# __beginExports__'),
)

export async function nixCurrentSystem() {
  try {
    console.time('nix currentSystem')
    return await nixEval('builtins.currentSystem')
  } finally {
    console.timeEnd('nix currentSystem')
  }
}

export async function nixGetTasksFromFlake(
  flakeUrl: string,
  flakeTaskAttributes: string[],
) {
  // remove tasks. prefix from each attribute path
  // as we pass the tasks attribute to the installable arg for nix eval
  const chompedTaskPaths = flakeTaskAttributes.map(taskAttr => {
    if (!taskAttr.startsWith('tasks.')) {
      throw new Error(
        'nixGetTasksFromFlake(): All tasks must be part of the tasks attribute on the flake outputs',
      )
    }
    return taskAttr.substring('tasks.'.length)
  })

  try {
    console.time('nix getTasksFromFlake')

    await nixEval(`:l ${path.join(__dirname, '../../nix/lib/getTasks.nix')}`)
    await nixEval(`:lf ${flakeUrl}`)

    const tasks = await nixEval(
      `
      let
        taskPaths = [ ${chompedTaskPaths
          .map(attr => `tasks.${attr}`)
          .join(' ')} ];
      in
      builtins.toJSON (formatTasks (flatten [
        ${chompedTaskPaths
          .map(
            attr => `
        (collectTasks {
          output = tasks.${attr};
          currentPath = ${JSON.stringify('tasks.' + attr)};
        })
        `,
          )
          .join('\n')}
        ]))
    `,
    )

    return tasks
  } finally {
    console.timeEnd('nix getTasksFromFlake')
  }
}

function collectTasks(
  output: any,
  originalFlakeUrl: string,
  resolvedOriginalFlakeUrl: string,
  passedTaskPaths: string[] = [],
): Task[] {
  return produce<(Task & NixTaskObject)[]>(output, draft => {
    for (const task of draft) {
      const allDiscoveredDeps: any = []

      function addDeps(objWithDeps: any) {
        Object.keys(objWithDeps.deps).forEach(depKey => {
          const value = objWithDeps.deps[depKey]
          const foundTaskForDependency =
            typeof value === 'string'
              ? draft.find((_task: any) => _task.id === value)
              : null

          if (value?.__type === 'taskOutput' && value?.deps != null) {
            value.ref = [originalFlakeUrl, value.flakeAttributePath].join('#')
            addDeps(value)
          } else if (foundTaskForDependency) {
            objWithDeps.deps[depKey] = foundTaskForDependency
            allDiscoveredDeps.push(foundTaskForDependency)
          }
        })
      }

      addDeps(task)

      task.allDiscoveredDeps = allDiscoveredDeps
      task.ref = [originalFlakeUrl, task.flakeAttributePath].join('#')
      task.exactRefMatch = passedTaskPaths.includes(task.flakeAttributePath)
      task.name = task.flakeAttributePath.split('.').at(-1)!
      // task.flakePath = flakePathToUse
      task.resolvedOriginalFlakeUrl = resolvedOriginalFlakeUrl
      task.originalFlakeUrl = originalFlakeUrl

      // strip the .tasks.<system> prefix from the attribute (for display purposes only)
      task.flakePrettyAttributePath = task.flakeAttributePath.replace(
        /^(tasks\.[\w\-_]+\.)/,
        '',
      )
      task.prettyRef = [
        task.originalFlakeUrl,
        task.flakePrettyAttributePath,
      ].join('#')
    }

    return draft
  })
}

async function rewriteTaskPaths(taskPaths: string[]) {
  const currentSystem = await nixCurrentSystem()

  return taskPaths.map(taskPath => {
    const [p, a] = taskPath.split('#')
    return [p, `tasks.${currentSystem}` + (a !== '' ? `.${a}` : '')].join('#')
  })
}

export async function nixGetTasks(
  taskPathsIn: string[],
  opts?: { forDevShell?: boolean },
) {
  const taskPaths = await rewriteTaskPaths(taskPathsIn)

  const taskSplitPaths = taskPaths.map(taskPath => {
    const split = taskPath.split('#')
    return { flakeUrl: split[0], attribute: split[1] }
  })

  // of all the provided tasks, get the unique flake refs
  const flakeUrls = _.uniq(taskSplitPaths.map(taskPath => taskPath.flakeUrl))

  // get tasks from each provided flake
  let tasks: Task[] = []

  for (const flakeUrl of flakeUrls) {
    const flakeTaskPaths = taskSplitPaths
      .filter(taskPath => taskPath.flakeUrl === flakeUrl)
      .map(taskPath => taskPath.attribute)

    const res = await nixGetTasksFromFlake(flakeUrl, flakeTaskPaths)

    let resolvedFlakeUrl = flakeUrl

    if (flakeUrl === '.') {
      const foundFlakeFile = await findUp('flake.nix')
      if (foundFlakeFile != null) {
        const rootDir = path.dirname(foundFlakeFile)
        const hasGit = await fss.pathExists(path.join(rootDir, '.git'))
        resolvedFlakeUrl = hasGit
          ? `git+file://${rootDir}`
          : `file://${rootDir}`
      }
    }

    tasks.push(...collectTasks(res, flakeUrl, resolvedFlakeUrl, flakeTaskPaths))
  }

  return tasks
}

export async function preBuild(tasks: Task[]) {
  console.time('nix store realise')
  try {
    const proc = execa(
      'nix-store',
      [
        '--realise',
        ..._.uniq(
          tasks.reduce(
            (curr, task) => [...curr, ...(task.storeDependencies ?? [])],
            [],
          ),
        ),
      ],
      {
        stdout: 'pipe',
        stderr: 'pipe',
      },
    )

    const stdout = readline.createInterface({
      input: proc.stdout as NodeJS.ReadableStream,
      terminal: false,
    })
    const stderr = readline.createInterface({
      input: proc.stderr as NodeJS.ReadableStream,
      terminal: false,
    })
    stdout.on('line', line => {
      // discard logging any lines where nix-store is just printing store paths
      if (line.match(/^\/nix\/store\/[a-z0-9]{32}-[\w\.-]+$/) == null) {
        console.log(line)
      }
    })
    stderr.on('line', line => {
      // discard logging warnings about paths not being added to garbage collector
      if (
        line.match(/the result might be removed by the garbage collector$/) ==
        null
      ) {
        process.stderr.write(line + '\n')
      }
    })

    await proc
  } finally {
    console.timeEnd('nix store realise')
  }
}

export async function getLazyTask(task: Task, ctx: any) {
  try {
    if (!task.flakeAttributePath.startsWith('tasks.')) {
      throw new Error(
        'getLazyTask(): Expected task attribute to start with tasks.',
      )
    }
    const chompedTaskPath = task.flakeAttributePath.substring('tasks.'.length)

    console.time('nix getLazyTask')

    const tasksOutput = await nixEval(
      `
      __toJSON (formatTasks(
        collectTasks {
          output = tasks.${chompedTaskPath}.getLazy (builtins.fromJSON ${JSON.stringify(
        JSON.stringify(ctx),
      )});
          currentPath = ${JSON.stringify('tasks.' + chompedTaskPath)};
        }
      ))
    `,
    )

    return collectTasks(
      tasksOutput,
      task.originalFlakeUrl,
      task.resolvedOriginalFlakeUrl,
      [],
    )[0]
  } finally {
    console.timeEnd('nix getLazyTask')
  }
}

export async function callTaskGetOutput(task: Task, currentOutput: any = {}) {
  try {
    console.time('nix taskGetOutput')

    const output = await nixEval(
      `
      __toJSON (${
        task.flakeAttributePath
      }.getOutput (builtins.fromJSON ${JSON.stringify(
        JSON.stringify(currentOutput ?? {}),
      )}))
    `,
    )

    return output
  } finally {
    console.timeEnd('nix taskGetOutput')
  }
}

export function getFlakeUrlLocalRepoPath(flakeUrl: string) {
  const parsed = url.parse(flakeUrl)
  if (parsed.protocol !== 'git+file:') return null
  if (!parsed.pathname) return null

  const params = new URLSearchParams(parsed.query ?? '')
  const dir = params.get('dir')

  return {
    repoRoot: parsed.pathname,
    flakeDirectory:
      dir != null ? path.join(parsed.pathname, dir) : parsed.pathname,
  }
}
