// Generated by CoffeeScript 1.7.1
window.AutomatorCommandCopy_coffeSource = '# \n\n\nclass AutomatorCommandCopy extends AutomatorCommand\n\n  clipboardText: ""\n\n  @replayFunction: (automatorRecorderAndPlayer, commandBeingPlayed) ->\n    automatorRecorderAndPlayer.worldMorph.processCopy null, commandBeingPlayed.clipboardText\n\n  constructor: (@clipboardText, automatorRecorderAndPlayer) ->\n    super(automatorRecorderAndPlayer)\n    # it\'s important that this is the same name of\n    # the class cause we need to use the static method\n    # replayFunction to replay the command\n    @automatorCommandName = "AutomatorCommandCopy"';
