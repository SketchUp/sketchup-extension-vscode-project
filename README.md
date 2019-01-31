# VSCode Project for SketchUp Extension Development

This is a boiler plate example project for setting up a VSCode project for SketchUp extension development.

Key features of this setup:

* When opening the project in VSCode you will be presented with a recommended set of VSCode extensions if you are missing any.
* Configured for Ruby auto-complete and code insight.
* SketchUp Ruby API supported in auto-complete.
* VSCode tasks for debugging Ruby source in SketchUp.
* Inline static analysis powered by RuboCop and RuboCop SketchUp.

![](https://github.com/SketchUp/sketchup-ruby-api-tutorials/wiki/images/VSCode/VSCodeSolargraphAutoComplete.png)

## Prerequisites

* Standalone Ruby installed on your development system. See [rubocop-sketchup manual](https://rubocop-sketchup.readthedocs.io/en/stable/installation/) for more details.
* The [Bundler gem](http://bundler.io/) to manage gem dependencies.

## Getting started

1. Clone the project to your machine.
2. From the command line install the require gem dependencies: `bundle install`
3. Start coding!

## Configuration

You might want to review the various configuration files to fit your project needs:

### `.rubocop.yml`

Configure what RuboCop should look for when analyzing your project. There are comments inline in the configuration file offering some help with what is pre-configured. For more details refer to the  [rubocop-sketchup manual](https://rubocop-sketchup.readthedocs.io/en/stable/).

### `.solargraph.yml`

You might want to update the `require_paths` to reflect one of your SketchUp installation paths to ensure Solargraph is able to provide full auto-complete for the SketchUp API.

### `.vscode/tasks.json`

Add/remove task launchers for relevant SketchUp versions. Follow the pattern for the existing launchers.

### `.editorconfig`

You might want to adjust this configuration file to suit your own coding style. This file is a [generic config file](https://editorconfig.org/) supported by many code editors.

## How To

### Debug in SketchUp

![](https://github.com/SketchUp/sketchup-ruby-api-tutorials/wiki/images/VSCode/VSCodeDebugging.gif)

**Note:** _Make sure you have [installed the required debugger](https://github.com/SketchUp/sketchup-ruby-api-tutorials/wiki/VSCode-Debugger-Setup#preparing-sketchup) dll/dylib to enable debugging in SketchUp._

You also need to make sure you are [loading the extension](https://github.com/SketchUp/sketchup-ruby-api-tutorials#loading-directly-from-the-repository) directly from your project's directory.

A visual guide is available in our [tutorials repository](https://code.visualstudio.com/docs/editor/debugging).

The short version is condensed here:

1. Set break points in the gutter bar next to the line numbers in the editor.
2. `View > Command Palette` (`Ctrl+Shift+P`)
3. Start typing `task`
4. Pick `Tasks: Run Task`
5. Pick `Debug in SketchUp 2018`
6. Wait for SketchUp to launch.
7. Go to the Debug tab in VSCode (`Ctrl+Shift+D`)
8. Pick `Listen for rdebug-ide` in the drop-down.
9. Click the `Start Debugging` button.

More details: https://github.com/SketchUp/sketchup-ruby-api-tutorials/wiki/VSCode-Debugger-Setup

## Further Reading

For the latest information on setting up rubocop-sketchup integration with VSCode, refer to:

* https://rubocop-sketchup.readthedocs.io/en/stable/integration_with_other_tools/
* https://github.com/SketchUp/sketchup-ruby-api-tutorials/wiki
