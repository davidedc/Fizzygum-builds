// Generated by CoffeeScript 1.7.1
window.AutomatorCommandScreenshot_coffeSource = '#\n\n\nclass AutomatorCommandScreenshot extends AutomatorCommand\n  screenShotImageName: null\n  # The screenshot can be of the entire\n  # world or of a particular morph (through\n  # the "take pic" menu entry.\n  # The screenshotTakenOfAParticularMorph flag\n  # remembers which case we are in.\n  # In the case that the screenshot is\n  # of a particular morph, the comparison\n  # will have to wait for the world\n  # to provide the image data (the take pic command\n  # will do it)\n  screenshotTakenOfAParticularMorph: false\n  @replayFunction: (automatorRecorderAndPlayer, commandBeingPlayed) ->\n    automatorRecorderAndPlayer.compareScreenshots(commandBeingPlayed.screenShotImageName, commandBeingPlayed.screenshotTakenOfAParticularMorph)\n\n\n  constructor: (@screenShotImageName, automatorRecorderAndPlayer, @screenshotTakenOfAParticularMorph = false ) ->\n    super(automatorRecorderAndPlayer)\n    # it\'s important that this is the same name of\n    # the class cause we need to use the static method\n    # replayFunction to replay the command\n    @automatorCommandName = "AutomatorCommandScreenshot"\n';
