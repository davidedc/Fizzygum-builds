// Generated by CoffeeScript 1.7.1
window.ProfilingDataCollector_coffeSource = '# Data collected at run time ///////////////////////////////////\n\n\nclass ProfilingDataCollector\n\n  # Overall profiling flags #########################\n\n  @overallProfilingEnabled: false\n\n  @enableProfiling: ->\n    @overallProfilingEnabled = true\n  @disableProfiling: ->\n    @overallProfilingEnabled = false\n\n  # Broken rectangles ###############################\n\n  @brokenRectsProfilingEnabled: false\n  @shortSessionCumulativeNumberOfBrokenRects: 0\n  @overallSessionCumulativeNumberOfBrokenRects: 0\n  @shortSessionMaxNumberOfBrokenRects: 0\n  @overallSessionMaxNumberOfBrokenRects: 0\n  @shortSessionCumulativeTotalAreaOfBrokenRects: 0\n  @overallSessionCumulativeTotalAreaOfBrokenRects: 0\n  @shortSessionMaxTotalAreaOfBrokenRects: 0\n  @overallSessionMaxTotalAreaOfBrokenRects: 0\n  @shortSessionCumulativeDuplicatedBrokenRects: 0\n  @overallSessionCumulativeDuplicatedBrokenRects: 0\n  @shortSessionMaxDuplicatedBrokenRects: 0\n  @overallSessionMaxDuplicatedBrokenRects: 0\n  @shortSessionCumulativeMergedSourceAndDestination: 0\n  @overallSessionCumulativeMergedSourceAndDestination: 0\n  @shortSessionMaxMergedSourceAndDestination: 0\n  @overallSessionMaxMergedSourceAndDestination: 0\n\n  @shortSessionCumulativeNumberOfAllocatedCanvases: 0\n  @shortSessionMaxNumberOfAllocatedCanvases: 0\n\n  @shortSessionCumulativeSizeOfAllocatedCanvases: 0\n\n  @shortSessionCumulativeNumberOfBlitOperations: 0\n  @shortSessionMaxNumberOfBlits: 0\n\n  @shortSessionCumulativeAreaOfBlits: 0\n  @shortSessionMaxAreaOfBlits: 0\n\n  @shortSessionBiggestBlitArea: 0\n\n  @shortSessionCumulativeTimeSpentRedrawing: 0\n  @shortSessionMaxTimeSpentRedrawing: 0\n\n  \n\n  # Broken rectangles ###############################\n\n  @enableBrokenRectsProfiling: ->\n    @overallProfilingEnabled = true\n    @brokenRectsProfilingEnabled = true\n  @disableBrokenRectsProfiling: ->\n    @brokenRectsProfilingEnabled = false\n\n  @profileBrokenRects: (brokenRectsArray, numberOfDuplicatedBrokenRects, numberOfMergedSourceAndDestination) ->\n    if !@overallProfilingEnabled or !@brokenRectsProfilingEnabled\n      return\n\n    numberOfBrokenRects = brokenRectsArray.length\n\n    @shortSessionCumulativeNumberOfBrokenRects += \\\n      numberOfBrokenRects\n    if numberOfBrokenRects > \\\n    @shortSessionMaxNumberOfBrokenRects\n      @shortSessionMaxNumberOfBrokenRects =\n        numberOfBrokenRects\n\n    @overallSessionCumulativeNumberOfBrokenRects += \\\n      numberOfBrokenRects\n    if numberOfBrokenRects > \\\n    @overallSessionMaxNumberOfBrokenRects\n      @overallSessionMaxNumberOfBrokenRects =\n        numberOfBrokenRects\n\n    totalAreaOfBrokenRects = 0\n    for eachRect in brokenRectsArray\n      if eachRect?\n        totalAreaOfBrokenRects += eachRect.area()\n\n    @shortSessionCumulativeTotalAreaOfBrokenRects += \\\n      totalAreaOfBrokenRects\n    @overallSessionCumulativeTotalAreaOfBrokenRects += \\\n      totalAreaOfBrokenRects\n    if totalAreaOfBrokenRects > \\\n    @shortSessionMaxTotalAreaOfBrokenRects\n      @shortSessionMaxTotalAreaOfBrokenRects =\n        totalAreaOfBrokenRects\n    if totalAreaOfBrokenRects > \\\n    @overallSessionMaxTotalAreaOfBrokenRects\n      @overallSessionMaxTotalAreaOfBrokenRects =\n        totalAreaOfBrokenRects\n\n    @shortSessionCumulativeDuplicatedBrokenRects += \\\n      numberOfDuplicatedBrokenRects\n    @overallSessionCumulativeDuplicatedBrokenRects += \\\n      numberOfDuplicatedBrokenRects\n    if numberOfDuplicatedBrokenRects > \\\n    @shortSessionMaxDuplicatedBrokenRects\n      @shortSessionMaxDuplicatedBrokenRects =\n        numberOfDuplicatedBrokenRects\n    if numberOfDuplicatedBrokenRects > \\\n    @overallSessionMaxDuplicatedBrokenRects\n      @overallSessionMaxDuplicatedBrokenRects =\n        numberOfDuplicatedBrokenRects\n\n    @shortSessionCumulativeMergedSourceAndDestination += \\\n      numberOfMergedSourceAndDestination\n    @overallSessionCumulativeMergedSourceAndDestination += \\\n      numberOfMergedSourceAndDestination\n    if numberOfMergedSourceAndDestination > \\\n    @shortSessionMaxMergedSourceAndDestination\n      @shortSessionMaxMergedSourceAndDestination =\n        numberOfMergedSourceAndDestination\n    if numberOfMergedSourceAndDestination > \\\n    @overallSessionMaxMergedSourceAndDestination\n      @overallSessionMaxMergedSourceAndDestination =\n        numberOfMergedSourceAndDestination\n\n\n';
