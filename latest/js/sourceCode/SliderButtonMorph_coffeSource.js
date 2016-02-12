// Generated by CoffeeScript 1.7.1
window.SliderButtonMorph_coffeSource = '# SliderButtonMorph ///////////////////////////////////////////////////\n# This is the handle in the middle of any slider.\n# Sliders (and hence this button)\n# are also used in the ScrollMorphs.\n\n# this comment below is needed to figure out dependencies between classes\n# REQUIRES globalFunctions\n\nclass SliderButtonMorph extends CircleBoxMorph\n  # this is so we can create objects from the object class name \n  # (for the deserialization process)\n  namedClasses[@name] = @prototype\n\n  # careful: Objects are shared with all the instances of this class.\n  # if you modify it, then all the objects will get the change\n  # but if you replace it with a new Color, then that will only affect the\n  # specific object instance. Same behaviour as with arrays.\n  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333\n  highlightColor: new Color 110, 110, 110\n  # see note above about Colors and shared objects\n  pressColor: new Color 100, 100, 100\n  normalColor: new Color 0, 0, 0\n  is3D: false\n\n  state: 0\n  STATE_NORMAL: 0\n  STATE_HIGHLIGHTED: 1\n  STATE_PRESSED: 2\n\n  constructor: (orientation) ->\n    super orientation\n    @color = @normalColor.copy()\n    @noticesTransparentClick = true\n    @alpha = 0.4\n\n  autoOrientation: ->\n      noOperation\n\n  # HandleMorph floatDragging and dropping:\n  rootForGrab: ->\n    @\n\n  reLayout: ->\n    super()\n    if @parent?\n      @orientation = @parent.orientation\n      if @orientation is "vertical"\n        bw = @parent.width() - 2\n        bh = Math.max bw, Math.round @parent.height() * @parent.ratio()\n        @silentRawSetExtent new Point bw, bh\n        posX = 1\n        posY = Math.min(\n          Math.round((@parent.value - @parent.start) * @parent.unitSize()),\n          @parent.height() - @height())\n      else\n        bh = @parent.height() - 2\n        bw = Math.max bh, Math.round @parent.width() * @parent.ratio()\n        @silentRawSetExtent new Point bw, bh\n        posY = 1\n        posX = Math.min(\n          Math.round((@parent.value - @parent.start) * @parent.unitSize()),\n          @parent.width() - @width())\n      @silentFullRawMoveTo new Point(posX, posY).add @parent.position()\n      @notifyChildrenThatParentHasReLayouted()\n\n  isFloatDraggable: ->\n    false\n\n  nonFloatDragging: (nonFloatDragPositionWithinMorphAtStart, pos) ->\n    @offset = pos.subtract nonFloatDragPositionWithinMorphAtStart\n    if world.hand.mouseButton and\n    @visibleBasedOnIsVisibleProperty() and\n    !@isCollapsed()\n      oldButtonPosition = @position()\n      if @parent.orientation is "vertical"\n        newX = @left()\n        newY = Math.max(\n          Math.min(@offset.y,\n          @parent.bottom() - @height()), @parent.top())\n      else\n        newY = @top()\n        newX = Math.max(\n          Math.min(@offset.x,\n          @parent.right() - @width()), @parent.left())\n      newPosition = new Point newX, newY\n      if !oldButtonPosition.eq newPosition\n        @fullRawMoveTo newPosition\n        @parent.updateValue()\n    \n  \n  #SliderButtonMorph events:\n  mouseEnter: ->\n    @state = @STATE_HIGHLIGHTED\n    @color = @highlightColor.copy()\n    @changed()\n  \n  mouseLeave: ->\n    @state = @STATE_NORMAL\n    @color = @normalColor.copy()\n    @changed()\n  \n  mouseDownLeft: (pos) ->\n    @state = @STATE_PRESSED\n    @color = @pressColor.copy()\n    @changed()\n  \n  mouseClickLeft: ->\n    @bringToForegroud()\n    @state = @STATE_HIGHLIGHTED\n    @color = @highlightColor.copy()\n    @changed()\n  \n';
