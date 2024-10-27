import { spawn } from 'node:child_process'
import { buffers, CANCEL, channel, eventChannel, runSaga } from 'redux-saga'
import stripAnsi from 'strip-ansi'
import { call, take } from 'redux-saga/effects'

const commandQueue = channel(buffers.expanding(100) as any)

export async function startNixRepl() {
  const task = runSaga({}, function* (): any {
    console.log('nix path: ', process.env.PKG_PATH_NIX_LAZY + '/bin/nix')
    const repl = spawn(process.env.PKG_PATH_NIX_LAZY + '/bin/nix', ['repl'], {})

    // repl.stdout.on('data', data => console.log('stdout', data.toString()))
    repl.stderr.on('data', data => console.log('stderr', data.toString()))

    repl.on('close', () => {
      // console.log('Nix repl exited')
      process.exit(1)
    })

    const startupChannel = yield call(() =>
      eventChannel(emitter => {
        const listener = (data: any) => {
          if (data.toString().includes('Type :? for help')) {
            emitter(true)
          }
        }
        repl.stderr.on('data', listener)
        return () => repl.stderr.off('data', listener)
      }),
    )
    yield take(startupChannel)
    startupChannel.close()

    // console.log('Nix repl started')

    try {
      while (true) {
        const action = yield take(commandQueue)

        const doneChannel = channel(buffers.none() as any)

        let responseOut = ''
        let responseErr = ''

        const stdoutListener = (data: any) => {
          responseOut += data.toString()
          if (data.toString().endsWith('\n')) {
            doneChannel.put(true)
          }
        }
        const stderrListener = (data: any) => (responseErr += data.toString())
        repl.stdout.on('data', stdoutListener)
        repl.stderr.on('data', stderrListener)

        try {
          // console.log('--->', action.command)
          repl.stdin.write(action.command.replaceAll('\n', ' ') + '\n') // remove new lines from input command as it will cause command to be sent to REPL

          yield take(doneChannel)

          let output: any = stripAnsi(responseOut)
          try {
            output = fromJSON(fromJSON(output))
          } catch (ex) {
            try {
              output = fromJSON(output)
            } catch (ex) {}
          }
          if (typeof output === 'string' && output.trim() === '') output = null

          if (
            responseErr.trim() !== '' &&
            (responseErr?.startsWith('error:') ||
              responseErr?.includes(
                "requires lock file changes but they're not allowed",
              )) &&
            !output
          ) {
            // console.log('got output', { responseErr, output })
            action.reject(new Error('Nix evaluation error: ' + responseErr))
          } else {
            action.resolve(output)
          }
        } finally {
          repl.stdout.off('data', stdoutListener)
          repl.stderr.off('data', stderrListener)
        }
      }

      yield take(CANCEL)
    } finally {
      repl.kill('SIGTERM')
    }
  })
}

function fromJSON(json: any) {
  // apply some fixes as Nix .toJSON sometimes produces invalid JSON
  // console.log('trying from JSON', json.replace(/([^\\])(\\\$)/, '$1$'))
  return JSON.parse(json.replace(/([^\\])(\\\$)/g, '$1$'))
}

export async function nixEval(command: string) {
  const responsePromise = new Promise((resolve, reject) =>
    commandQueue.put({ command, resolve, reject }),
  )
  return await responsePromise
}
