# nix-task

> Not ready for use yet, no usable packages are exported from this repository

nix-task is a task/action runner that lets you use the Nix language to write simple tasks or entire CI/CD pipelines, as an alternative to tools like Make, Dagger, Taskfile, etc.

It is not a replacement of CI/CD runners like GitLab CI or GitHub Actions, and instead is designed to complement these tools by being called by CI/CD runners. This allows pipelines to be authored and run agnostic to any particular CI/CD runner.

## Examples

See [examples/nixMathHomework/flake.nix](examples/nixMathHomework/flake.nix) as an example.

## Documentation

Tasks will be collected recursively from the provided attr path, unless any attrset that is encountered has `_nixTaskDontRecurseTasks` set to true.

### Nix library

#### `nix-task.lib.mkTask`

```
nix-task.lib.mkTask({
  # other tasks that this task is dependant on
  deps =? [ other tasks ];

  # nix packages that should be made available to the PATH for task execution
  path =? [ nix pkgs here ];

  # script to run for this task
  run = string | { deps }: string;

  # script to run when entering a shell using `nix-task shell`
  shellHook ?= string | { deps }: string;

  id =? string;
})
```

### Bash stdlib available to tasks

#### `$out`

Returns the path to an output directory where output artifacts can be stored. For this directory to be available, `artifacts = [ "output" "file" "names" "here" ];` needs to be set on the `mkTask`.

#### `$IMPURE_HOME`

Returns the path to your user home directory.

#### `taskSetOutput <json>`

Sets `<json>` as the output of this task, which can be used by other tasks that depend on this task.

#### `taskRunInBackground <command>`

Runs `<command>` in the background of this task. Will be sent a SIGTERM when the task has finished and will wait for the process to gracefully terminate.

#### `taskRunFinally <command>`

Runs `<command>` when this task finishes either successfully or on error.

#### `taskGetDeps`

Dumps the deps and their outputs as JSON.

## License

Licensed under the MIT License.

View the full license [here](https://raw.githubusercontent.com/madjam002/nix-task/master/LICENSE).

## Solana-Nix-AI Workflow Integration

This section outlines the conceptual integration of Solana blockchain events with Nix-managed AI workflows, facilitated by various Nix tasks and example flakes within this repository.

### Conceptual Architecture

The proposed architecture involves:
1.  **Solana Smart Contract:** Emits observable events or modifies account state.
2.  **Off-Chain Listener (e.g., Geyser/Polling):** Monitors the Solana blockchain for these events.
3.  **Nix Task Trigger:** The listener, upon detecting an event, triggers a specific Nix task.
4.  **Nix Flake Signatures:** Solana event data can contain "signatures" (e.g., attribute paths, parameters) that guide which Nix task to execute or how.
5.  **AI Interaction:** Triggered Nix tasks interact with AI services.
6.  **Nix Scheduler:** Manages and executes Nix tasks based on triggers.

### Implemented Nix Tasks for this Workflow

The following tasks have been created to demonstrate parts of this workflow:

*   **`tasks.gemini`**: (Existing task) Represents a general Gemini CLI interaction.
*   **`tasks.run-gemini-cli`**: A task configured to run the `gemini-cli` in non-interactive mode with an empty prompt, simulating automated AI interaction.
    *   **Usage:** `nix run .#tasks.run-gemini-cli`
*   **`tasks.solana-ai-trigger`**: Simulates an AI interaction triggered by a Solana smart contract event. This task acts as a placeholder for actual AI API calls.
    *   **Usage:** `nix run .#tasks.solana-ai-trigger`
*   **`tasks.process-solana-nar`**: Demonstrates how a Nix task can consume Solana data packaged as a NAR (Nix Archive) file. It expects the `SOLANA_NAR_PATH` environment variable to point to the NAR file.
    *   **Usage:** `SOLANA_NAR_PATH=/path/to/your/solana.nar nix run .#tasks.process-solana-nar`
*   **`tasks.helius-block-processor`**: Simulates an off-chain service polling the Helius API for Solana blocks. It represents the logic for fetching blockchain data and identifying derivations needed for the Nix build system.
    *   **Usage:** `nix run .#tasks.helius-block-processor`
*   **`tasks.solana-nix-trigger-interpreter`**: Simulates the off-chain interpretation of Solana event data. It extracts a "Nix flake signature" (e.g., a flake attribute path) from the `SOLANA_EVENT_DATA` environment variable and simulates triggering the corresponding Nix task.
    *   **Usage:** `SOLANA_EVENT_DATA="some event data with my-task" nix run .#tasks.solana-nix-trigger-interpreter`

### Example Flakes for Workflow Demonstration

*   **`examples/gemini-caller-flake`**: A flake that demonstrates how to call the `run-gemini-cli` task from an external flake. Its `devShell` executes the `run-gemini-cli` task upon entering the shell.
    *   **Usage:** `nix develop ./examples/gemini-caller-flake`
*   **`examples/gemini-input-flake`**: A simple flake that consumes the `gemini-caller-flake`, showcasing a chained flake dependency. Its `devShell` re-exports the `devShell` from `gemini-caller-flake`.
    *   **Usage:** `nix develop ./examples/gemini-input-flake`
*   **`flakes/all-repos`**: A "meta-flake" designed to aggregate multiple project repositories. It demonstrates how to include external repositories as inputs and can be extended to expose their packages or define combined development shells, laying the groundwork for managing a large number of interdependent projects within the Nix ecosystem.
    *   **Usage:** `nix develop ./flakes/all-repos` (to enter a shell with aggregated packages)
    *   **Usage:** `nix build ./flakes/all-repos#packages.example-package` (to build an example package from an aggregated repo)

### Testing the Workflow

To test the various components:

1.  **Run individual tasks:** Use `nix run .#tasks.<task-name>` with appropriate environment variables (e.g., `SOLANA_NAR_PATH`, `SOLANA_EVENT_DATA`) as described above.
2.  **Test example flakes:** Use `nix develop ./examples/<flake-name>` to enter their development shells and observe their behavior.
3.  **Test the meta-flake:** Use `nix develop ./flakes/all-repos` to see the aggregated environment, or `nix build ./flakes/all-repos#packages.example-package` to build a package from an aggregated repository.