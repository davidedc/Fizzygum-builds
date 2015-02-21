class ProfilerData
  
  @reactiveValues_valueRecalculations: 0
  @reactiveValues_signatureCalculations: 0
  @reactiveValues_signatureComparison: 0
  @reactiveValues_argumentInvalidations: 0
  @reactiveValues_valueInvalidations: 0
  @reactiveValues_parentValuesRechecks: 0
  @reactiveValues_createdGroundVals: 0
  @reactiveValues_createdBasicCalculatedValues: 0

  @resetReactiveValuesCounts: ->
    @reactiveValues_valueRecalculations = 0
    @reactiveValues_signatureCalculations = 0
    @reactiveValues_signatureComparison = 0
    @reactiveValues_argumentInvalidations = 0
    @reactiveValues_valueInvalidations = 0
    @reactiveValues_parentValuesRechecks = 0
    @reactiveValues_createdGroundVals = 0
    @reactiveValues_createdBasicCalculatedValues = 0



  @coffeeScriptSourceOfThisClass: '''
class ProfilerData
  
  @reactiveValues_valueRecalculations: 0
  @reactiveValues_signatureCalculations: 0
  @reactiveValues_signatureComparison: 0
  @reactiveValues_argumentInvalidations: 0
  @reactiveValues_valueInvalidations: 0
  @reactiveValues_parentValuesRechecks: 0
  @reactiveValues_createdGroundVals: 0
  @reactiveValues_createdBasicCalculatedValues: 0

  @resetReactiveValuesCounts: ->
    @reactiveValues_valueRecalculations = 0
    @reactiveValues_signatureCalculations = 0
    @reactiveValues_signatureComparison = 0
    @reactiveValues_argumentInvalidations = 0
    @reactiveValues_valueInvalidations = 0
    @reactiveValues_parentValuesRechecks = 0
    @reactiveValues_createdGroundVals = 0
    @reactiveValues_createdBasicCalculatedValues = 0


  '''

# an Arg wraps a Val that is an input to the
# calculation of the current Val.
# an Arg for example contains the signature that
# the input val had when the Val was calculated.
# The signature could be a custom signature that is
# only relevant to this Val. So it contains several
# pieces of information about each input val, that are
# specific to the context of this Val (hence, we
# can't put it in the input arg val, we need to
# put this Arg which lives in the context of this
# Val).

# REQUIRES ProfilerData

class Arg
  valWrappedByThisArg: null
  maybeChangedSinceLastCalculation: true
  
  # an argument can either be
  #  1. connected to a parent
  #  2. connected to a child
  #  3. connected to a local value
  # and this is determined when the
  # value that depends on this argument is created.
  # (the parent/child is dynamic, but the nature of
  # the argument is decided early)
  directlyCalculatedFromParent: false
  fromChild: false
  fromLocal: false

  # this flag tracks whether this argument
  # directly or indirectly depends on a parent
  # value. So if @directlyCalculatedFromParent is true
  # then this is true as well. But this could be true
  # even is @directlyCalculatedFromParent is false,
  # because you could have an argument which
  # is connected to a value in a child BUT
  # that value might directly or indirectly
  # depend on a parent value at some stage.
  directlyOrIndirectlyCalculatedFromParent: false
  
  morphContainingThisArg: null
  args: null
  markedForRemoval: false
  # we keep the vals of the args we
  # used to calculate the last val. This is so
  # we can keep an eye on how the args
  # change. If they change back to the original
  # vals we used then we can propagate this
  # "OK our last calculation actually holds"
  # information WITHOUT triggering a recalculation.
  @signatureAtLastCalculation: ""
  @id: ""

  constructor: (@valWrappedByThisArg, @valContainingThisArg) ->
    @morphContainingThisArg = @valContainingThisArg.ownerMorph
    @args = @valContainingThisArg.args
    @id = @valWrappedByThisArg.id
    @args.argById[@id] = @

  fetchVal: () ->
    @valWrappedByThisArg.fetchVal()

  ################################################
  #  signature checking / calculation
  ################################################

  # we give the opportunity to specify a custom signature
  # for args, in case we have a signature that
  # is more efficient considering the type of
  # calculation that we are going to do
  getSignatureOrCustomSignatureOfWrappedVal: () ->
    if @args.customSignatureMethod?
      theValSignature = @args.customSignatureMethod valWrappedByThisArg
    else
      theValSignature = @valWrappedByThisArg.lastCalculatedValContent.signature
      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "fetching default signature of argument: " + @id + " : " + theValSignature
    theValSignature = theValSignature + @markedForRemoval

    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      console.log "calculated signature of argument: " + @id + " : " + theValSignature

    return theValSignature

  semanticallyChangedSinceLastValCalculation: () ->
    if @getSignatureOrCustomSignatureOfWrappedVal() != @signatureAtLastCalculation
      return true
    else
      return false

  # an Argument of this value has notified its change
  # but we want to check, based on either its default
  # signature or a custom signature, wether its
  # value changed from when we calculated this value
  # the last time. Following this check, we might
  # "heal"/break the value and potentially
  # propagate the change
  checkBasedOnSignature: () ->

    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      console.log "checking signature of argument: " + @id

    # the unique identifier of a val is given by
    # its name as a string and the id of the Morph it
    # belongs to. For localVals this is ever so slightly
    # inneficient as you could always index them through
    # an integer, which would be faster, but probably
    # the improvement would be "in the noise".
    signatureOfArgUsedInLastCalculation =
      @signatureAtLastCalculation
    # this is the case where a child has been added:
    # the arg wasn't there before
    if signatureOfArgUsedInLastCalculation == undefined
      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "argument: " + @id + " is undefined, breaking and returning "
      @break()
      return undefined

    # if the arg which has maybe changed doesn't know
    # its val then we just mark the arg as broken
    # and we do nothing else
    if @valWrappedByThisArg.lastCalculatedValContentMaybeOutdated
      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "argument: " + @id + " is broken on its own anyways, breaking this arg"
      @break()
    else
      # if the val that asserts change claims that its val
      # is actually correct then we proceed to check its
      # signature to check whether it changed since the
      # last time we calculated our val.
      # We let the user provide her own signature calculation
      # method for args: this is because for the purpose of
      # the calculation of this val, there might be a better
      # notion of equivalency of the args that lets us be
      # more tolerant of changes (which means less invalidation which
      # means less recalculations which means fewer invalidations further
      # on). An example of such "wider" equivalency is for the HSV color
      # values if we need to convert them to RGB. Every HSV value
      # with V set to zero is equivalent in this respect because it
      # always means black.
      if @semanticallyChangedSinceLastValCalculation()
        # argsMaybeChangedSinceLastCalculation is an object, we add
        # a property to it for each dirty arg, so we delete
        # such property when we verify it's actually healthy.
        if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
          console.log "argument: " + @id + " has equal signature to one used for last calculation, healing"
        @heal()
      else
        if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
          console.log "argument: " + @id + " has different signature to one used for last calculation, breaking"
        @break()


  updateSignature: () ->
    oldSig = @signatureAtLastCalculation
    newSig = @getSignatureOrCustomSignatureOfWrappedVal()
    signatureChanged = false
    if newSig != oldSig
        signatureChanged = true
    @signatureAtLastCalculation = newSig
    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      if signatureChanged
      	console.log "checked signature of argument: " + @id + " and it changed was: " + oldSig + " now is: " + newSig
      else
      	console.log "checked signature of argument: " + @id + " and it didn't change was: " + oldSig + " now is: " + newSig
    return signatureChanged

  updateSignatureAndHeal: () ->
    signatureChanged = @updateSignature()
    @heal()
    return signatureChanged


  ################################################
  #  breaking / healing
  ################################################

  heal: () ->
    @maybeChangedSinceLastCalculation = false
    delete @args.argsMaybeChangedSinceLastCalculationById[@id]
    @args.countOfDamaged--
    # check implications of argument being healed: it
    # might be that this means that the value heals as
    # well and propagates healing
    if !@valContainingThisArg.directlyOrIndirectlyDependsOnAParentVal
      @valContainingThisArg.checkAndPropagateChangeBasedOnArgChange()

  break: () ->
    @maybeChangedSinceLastCalculation = true
    @args.argsMaybeChangedSinceLastCalculationById[@id] = true
    @args.countOfDamaged++
    # check implications of argument being broken: it
    # might be that this means that the value breaks as
    # well and propagates damage
    if !@valContainingThisArg.directlyOrIndirectlyDependsOnAParentVal
      @valContainingThisArg.checkAndPropagateChangeBasedOnArgChange()


  ################################################
  #  removal
  ################################################

  # we don't completely destroy the argument
  # (lieke removeFromArgs does)
  # for the simple reason that we do need to
  # remember its signature when the value
  # was last calculated.
  markForRemoval: () ->
    @markedForRemoval = true
    @turnIntoArgNotDirectlyNorIndirectlyDependingOnParent()
    @morphContainingThisArg.argMightHaveChanged(valWrappedByThisArg)

  unmarkForRemoval: () ->
    @markedForRemoval = false

  removeArgIfMarkedForRemoval: () ->
    if @markedForRemoval
      @removeFromArgs()
      return true
    else
      return false

  removeFromArgs: () ->
    #@turnIntoArgNotDirectlyNorIndirectlyDependingOnParent()
    delete @args.argById[@id]
    if @args.argsMaybeChangedSinceLastCalculationById[@id]?
      delete @args.argsMaybeChangedSinceLastCalculationById[@id]
      @args.countOfDamaged--



  ################################################
  #  disconnection
  ################################################

  disconnectChildArg: () ->
    @fromChild = false
    delete @args.childrenArgByName[@valContainingThisArg.valName]
    @args.childrenArgByNameCount[@valContainingThisArg.valName]--
    @markForRemoval()

  disconnectParentArg: () ->
    @directlyCalculatedFromParent = false
    @directlyOrIndirectlyCalculatedFromParent = true
    delete @args.parentArgByName[@valContainingThisArg.valName]
    @markForRemoval()

  ################################################
  #  (un)turning into argument
  #  directly or indirectly depending on parent
  ################################################

  turnIntoArgDirectlyOrIndirectlyDependingOnParent: () ->
    @args.calculatedDirectlyOfIndirectlyFromParentById[@valWrappedByThisArg.id] = true
    if !@args.calculatedDirectlyOfIndirectlyFromParentById[@valWrappedByThisArg.id]?
        @args.calculatedDirectlyOfIndirectlyFromParentByIdCount++
    @valContainingThisArg.directlyOrIndirectlyDependsOnAParentVal = true
    @directlyOrIndirectlyCalculatedFromParent = true

    for cv in @valContainingThisArg.localValsAffectedByChangeOfThisVal
      cv.stainValCalculatedFromParent @valContainingThisArg
    if @ownerMorph.parent?
      v = @morphContainingThisArg.parent.morphValsDependingOnChildrenVals[@valName]
      for k in v
        k.stainValCalculatedFromParent @valContainingThisArg



  turnIntoArgNotDirectlyNorIndirectlyDependingOnParent: () ->
    # note that we might turn also an Argument that we know
    # directly depends on a parent. The reason is that
    # we might be removing the parent, in which case
    # this morph might cease to depend on parent values.
    # we need to find out by doing the full works here.

    # this changes @directlyOrIndirectlyDependsOnAParentVal if there are no
    # more args depending on parent vals
    if @args.calculatedDirectlyOfIndirectlyFromParentById[@valWrappedByThisArg.id]?
        @args.calculatedDirectlyOfIndirectlyFromParentByIdCount--
    delete @args.calculatedDirectlyOfIndirectlyFromParentById[@valWrappedByThisArg.id]
    @directlyOrIndirectlyCalculatedFromParent = false

    if @args.calculatedDirectlyOfIndirectlyFromParentByIdCount > 0
      @valContainingThisArg.directlyOrIndirectlyDependsOnAParentVal = false

      # this means that the arg that has unstained itself
      # was the last and only reason why this val was stained
      # so we proceed to unstain ourselves
      for cv in @valContainingThisArg.localValsAffectedByChangeOfThisVal
        cv.unstainValCalculatedFromParent @valContainingThisArg
      if @valContainingThisArg.ownerMorph.parent?
        v = @morphContainingThisArg.parent.morphValsDependingOnChildrenVals[@valContainingThisArg.valName]
        for k in v
          k.unstainValCalculatedFromParent @valContainingThisArg

  @coffeeScriptSourceOfThisClass: '''
# an Arg wraps a Val that is an input to the
# calculation of the current Val.
# an Arg for example contains the signature that
# the input val had when the Val was calculated.
# The signature could be a custom signature that is
# only relevant to this Val. So it contains several
# pieces of information about each input val, that are
# specific to the context of this Val (hence, we
# can't put it in the input arg val, we need to
# put this Arg which lives in the context of this
# Val).

# REQUIRES ProfilerData

class Arg
  valWrappedByThisArg: null
  maybeChangedSinceLastCalculation: true
  
  # an argument can either be
  #  1. connected to a parent
  #  2. connected to a child
  #  3. connected to a local value
  # and this is determined when the
  # value that depends on this argument is created.
  # (the parent/child is dynamic, but the nature of
  # the argument is decided early)
  directlyCalculatedFromParent: false
  fromChild: false
  fromLocal: false

  # this flag tracks whether this argument
  # directly or indirectly depends on a parent
  # value. So if @directlyCalculatedFromParent is true
  # then this is true as well. But this could be true
  # even is @directlyCalculatedFromParent is false,
  # because you could have an argument which
  # is connected to a value in a child BUT
  # that value might directly or indirectly
  # depend on a parent value at some stage.
  directlyOrIndirectlyCalculatedFromParent: false
  
  morphContainingThisArg: null
  args: null
  markedForRemoval: false
  # we keep the vals of the args we
  # used to calculate the last val. This is so
  # we can keep an eye on how the args
  # change. If they change back to the original
  # vals we used then we can propagate this
  # "OK our last calculation actually holds"
  # information WITHOUT triggering a recalculation.
  @signatureAtLastCalculation: ""
  @id: ""

  constructor: (@valWrappedByThisArg, @valContainingThisArg) ->
    @morphContainingThisArg = @valContainingThisArg.ownerMorph
    @args = @valContainingThisArg.args
    @id = @valWrappedByThisArg.id
    @args.argById[@id] = @

  fetchVal: () ->
    @valWrappedByThisArg.fetchVal()

  ################################################
  #  signature checking / calculation
  ################################################

  # we give the opportunity to specify a custom signature
  # for args, in case we have a signature that
  # is more efficient considering the type of
  # calculation that we are going to do
  getSignatureOrCustomSignatureOfWrappedVal: () ->
    if @args.customSignatureMethod?
      theValSignature = @args.customSignatureMethod valWrappedByThisArg
    else
      theValSignature = @valWrappedByThisArg.lastCalculatedValContent.signature
      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "fetching default signature of argument: " + @id + " : " + theValSignature
    theValSignature = theValSignature + @markedForRemoval

    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      console.log "calculated signature of argument: " + @id + " : " + theValSignature

    return theValSignature

  semanticallyChangedSinceLastValCalculation: () ->
    if @getSignatureOrCustomSignatureOfWrappedVal() != @signatureAtLastCalculation
      return true
    else
      return false

  # an Argument of this value has notified its change
  # but we want to check, based on either its default
  # signature or a custom signature, wether its
  # value changed from when we calculated this value
  # the last time. Following this check, we might
  # "heal"/break the value and potentially
  # propagate the change
  checkBasedOnSignature: () ->

    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      console.log "checking signature of argument: " + @id

    # the unique identifier of a val is given by
    # its name as a string and the id of the Morph it
    # belongs to. For localVals this is ever so slightly
    # inneficient as you could always index them through
    # an integer, which would be faster, but probably
    # the improvement would be "in the noise".
    signatureOfArgUsedInLastCalculation =
      @signatureAtLastCalculation
    # this is the case where a child has been added:
    # the arg wasn't there before
    if signatureOfArgUsedInLastCalculation == undefined
      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "argument: " + @id + " is undefined, breaking and returning "
      @break()
      return undefined

    # if the arg which has maybe changed doesn't know
    # its val then we just mark the arg as broken
    # and we do nothing else
    if @valWrappedByThisArg.lastCalculatedValContentMaybeOutdated
      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "argument: " + @id + " is broken on its own anyways, breaking this arg"
      @break()
    else
      # if the val that asserts change claims that its val
      # is actually correct then we proceed to check its
      # signature to check whether it changed since the
      # last time we calculated our val.
      # We let the user provide her own signature calculation
      # method for args: this is because for the purpose of
      # the calculation of this val, there might be a better
      # notion of equivalency of the args that lets us be
      # more tolerant of changes (which means less invalidation which
      # means less recalculations which means fewer invalidations further
      # on). An example of such "wider" equivalency is for the HSV color
      # values if we need to convert them to RGB. Every HSV value
      # with V set to zero is equivalent in this respect because it
      # always means black.
      if @semanticallyChangedSinceLastValCalculation()
        # argsMaybeChangedSinceLastCalculation is an object, we add
        # a property to it for each dirty arg, so we delete
        # such property when we verify it's actually healthy.
        if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
          console.log "argument: " + @id + " has equal signature to one used for last calculation, healing"
        @heal()
      else
        if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
          console.log "argument: " + @id + " has different signature to one used for last calculation, breaking"
        @break()


  updateSignature: () ->
    oldSig = @signatureAtLastCalculation
    newSig = @getSignatureOrCustomSignatureOfWrappedVal()
    signatureChanged = false
    if newSig != oldSig
        signatureChanged = true
    @signatureAtLastCalculation = newSig
    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      if signatureChanged
      	console.log "checked signature of argument: " + @id + " and it changed was: " + oldSig + " now is: " + newSig
      else
      	console.log "checked signature of argument: " + @id + " and it didn't change was: " + oldSig + " now is: " + newSig
    return signatureChanged

  updateSignatureAndHeal: () ->
    signatureChanged = @updateSignature()
    @heal()
    return signatureChanged


  ################################################
  #  breaking / healing
  ################################################

  heal: () ->
    @maybeChangedSinceLastCalculation = false
    delete @args.argsMaybeChangedSinceLastCalculationById[@id]
    @args.countOfDamaged--
    # check implications of argument being healed: it
    # might be that this means that the value heals as
    # well and propagates healing
    if !@valContainingThisArg.directlyOrIndirectlyDependsOnAParentVal
      @valContainingThisArg.checkAndPropagateChangeBasedOnArgChange()

  break: () ->
    @maybeChangedSinceLastCalculation = true
    @args.argsMaybeChangedSinceLastCalculationById[@id] = true
    @args.countOfDamaged++
    # check implications of argument being broken: it
    # might be that this means that the value breaks as
    # well and propagates damage
    if !@valContainingThisArg.directlyOrIndirectlyDependsOnAParentVal
      @valContainingThisArg.checkAndPropagateChangeBasedOnArgChange()


  ################################################
  #  removal
  ################################################

  # we don't completely destroy the argument
  # (lieke removeFromArgs does)
  # for the simple reason that we do need to
  # remember its signature when the value
  # was last calculated.
  markForRemoval: () ->
    @markedForRemoval = true
    @turnIntoArgNotDirectlyNorIndirectlyDependingOnParent()
    @morphContainingThisArg.argMightHaveChanged(valWrappedByThisArg)

  unmarkForRemoval: () ->
    @markedForRemoval = false

  removeArgIfMarkedForRemoval: () ->
    if @markedForRemoval
      @removeFromArgs()
      return true
    else
      return false

  removeFromArgs: () ->
    #@turnIntoArgNotDirectlyNorIndirectlyDependingOnParent()
    delete @args.argById[@id]
    if @args.argsMaybeChangedSinceLastCalculationById[@id]?
      delete @args.argsMaybeChangedSinceLastCalculationById[@id]
      @args.countOfDamaged--



  ################################################
  #  disconnection
  ################################################

  disconnectChildArg: () ->
    @fromChild = false
    delete @args.childrenArgByName[@valContainingThisArg.valName]
    @args.childrenArgByNameCount[@valContainingThisArg.valName]--
    @markForRemoval()

  disconnectParentArg: () ->
    @directlyCalculatedFromParent = false
    @directlyOrIndirectlyCalculatedFromParent = true
    delete @args.parentArgByName[@valContainingThisArg.valName]
    @markForRemoval()

  ################################################
  #  (un)turning into argument
  #  directly or indirectly depending on parent
  ################################################

  turnIntoArgDirectlyOrIndirectlyDependingOnParent: () ->
    @args.calculatedDirectlyOfIndirectlyFromParentById[@valWrappedByThisArg.id] = true
    if !@args.calculatedDirectlyOfIndirectlyFromParentById[@valWrappedByThisArg.id]?
        @args.calculatedDirectlyOfIndirectlyFromParentByIdCount++
    @valContainingThisArg.directlyOrIndirectlyDependsOnAParentVal = true
    @directlyOrIndirectlyCalculatedFromParent = true

    for cv in @valContainingThisArg.localValsAffectedByChangeOfThisVal
      cv.stainValCalculatedFromParent @valContainingThisArg
    if @ownerMorph.parent?
      v = @morphContainingThisArg.parent.morphValsDependingOnChildrenVals[@valName]
      for k in v
        k.stainValCalculatedFromParent @valContainingThisArg



  turnIntoArgNotDirectlyNorIndirectlyDependingOnParent: () ->
    # note that we might turn also an Argument that we know
    # directly depends on a parent. The reason is that
    # we might be removing the parent, in which case
    # this morph might cease to depend on parent values.
    # we need to find out by doing the full works here.

    # this changes @directlyOrIndirectlyDependsOnAParentVal if there are no
    # more args depending on parent vals
    if @args.calculatedDirectlyOfIndirectlyFromParentById[@valWrappedByThisArg.id]?
        @args.calculatedDirectlyOfIndirectlyFromParentByIdCount--
    delete @args.calculatedDirectlyOfIndirectlyFromParentById[@valWrappedByThisArg.id]
    @directlyOrIndirectlyCalculatedFromParent = false

    if @args.calculatedDirectlyOfIndirectlyFromParentByIdCount > 0
      @valContainingThisArg.directlyOrIndirectlyDependsOnAParentVal = false

      # this means that the arg that has unstained itself
      # was the last and only reason why this val was stained
      # so we proceed to unstain ourselves
      for cv in @valContainingThisArg.localValsAffectedByChangeOfThisVal
        cv.unstainValCalculatedFromParent @valContainingThisArg
      if @valContainingThisArg.ownerMorph.parent?
        v = @morphContainingThisArg.parent.morphValsDependingOnChildrenVals[@valContainingThisArg.valName]
        for k in v
          k.unstainValCalculatedFromParent @valContainingThisArg
  '''

# Args are the input based on which a val is calculated
# There are several pieces of "aggregate" information that
# we keep about args considered together e.g. whether
# any of them has changed since the last calculation of the
# Val, or which ones directly or indirectly depend on a Parent
# Val.

# REQUIRES ProfilerData

class Args
  # some accessors gere to get to the
  # actual arguments. You can get to all
  # of them by Id of the Value
  # or, in the care of an argument connected
  # to a parent morph, by the value name
  # (since there is only one Arg connected
  # to the parent for each value name, which is
  # not the case for children Args as
  # onviously you may have many children and hence
  # many arguments)
  argById: null
  parentArgByName: null
  childrenArgByName: null
  # we want to group together all children
  # values under the same name
  # so we keep this count separate
  # rather than counting navigating the keys
  childrenArgByNameCount: null
  localArgByName: null
  calculatedDirectlyOfIndirectlyFromParentById: null
  calculatedDirectlyOfIndirectlyFromParentByIdCount: 0

  countOfDamaged: 0
  morphContainingTheseArgs: null

  # just some flags to keep track of which
  # args might have changed. Again, we might
  # not know for sure because we don't necessarily
  # recalculate them
  argsMaybeChangedSinceLastCalculationById: null

  constructor: (@valContainingTheseArgs) ->
    @argById = {}
    @parentArgByName = {}
    @childrenArgByName = {}
    @childrenArgByNameCount = {}
    @localArgByName = {}
    @calculatedDirectlyOfIndirectlyFromParentById = {}
    @argsMaybeChangedSinceLastCalculationById = {}

    @morphContainingTheseArgs = @valContainingTheseArgs.ownerMorph


  ################################################
  #  breaking / healing
  ################################################

  healAll: () ->
    for eachArg of argsMaybeChangedSinceLastCalculationById
      eachArg.heal()


  ################################################
  #  accessors
  ################################################

  getByVal: (theVal) ->
    return @getById theVal.id

  ################################################
  #  setup methods - these are called in the
  #  constructors of each value to prepare
  #  for the arguments.
  ################################################

  # for local arguments, you can
  # actually create the arguments as they are static
  setup_AddAllLocalArgVals: (localInputVals) ->
    for each in localInputVals
      # connecting arguments that come from local values is
      # easier because those links are static, they are done
      # at construction time once and for all
      each.localValsAffectedByChangeOfThisVal.push @valContainingTheseArgs
      newArg = new Arg localInputVals, @valContainingTheseArgs
      newArg.fromLocal = true
      @localArgByName[localInputVals.valueName] = newArg

  # you can't create the actual arguments yet as these
  # arguments will be connected dynamically. we just prepare
  # some a structure in the morph so we'll be able
  # to connect the actual values in the morph's
  # childAdded and childRemoved methods
  setup_AddAllParentArgNames: (parentArgsNames) ->
    # ORIGINAL CODE:
    #for each var in parentArgsNames
    #  if !@ownerMorph.morphValsDirectlyDependingOnParentVals[each]?
    #    @ownerMorph.morphValsDirectlyDependingOnParentVals[each] = {}
    #  @ownerMorph.morphValsDirectlyDependingOnParentVals[each][@valName] = @

    for eachVar in parentArgsNames
      @morphContainingTheseArgs.morphValsDirectlyDependingOnParentVals[eachVar]?= {}
      @morphContainingTheseArgs.morphValsDirectlyDependingOnParentVals[eachVar][@valContainingTheseArgs.valName] = @valContainingTheseArgs

  # you can't create the actual arguments yet as these
  # arguments will be connected dynamically. we just prepare
  # some a structure in the morph so we'll be able
  # to connect the actual values in the morph's
  # childAdded and childRemoved methods
  setup_AddAllChildrenArgNames: (childrenArgsNames) ->
    #debugger
    for eachVar in childrenArgsNames
      @morphContainingTheseArgs.morphValsDependingOnChildrenVals[eachVar] ?= {}
      @morphContainingTheseArgs.morphValsDependingOnChildrenVals[eachVar][@valContainingTheseArgs.valName] = @valContainingTheseArgs

  ################################################
  #  argument connenction methods
  #  these are called when Morphs are moved
  #  around so we need to connect/disconnect
  #  the arguments of each value to/from the
  #  (new) parent/children
  ################################################

  # check whether you are reconnecting
  # an arg that was temporarily
  # disconnected
  tryToReconnectDisconnectedArgFirst: (parentOrChildVal) ->
    existingArg = @argById[parentOrChildVal.id]
    if existingArg?
      existingArg.markedForRemoval = false
      existingArg.valContainingThisArg.argMightHaveChanged(parentOrChildVal)
      return existingArg
    return null


  # connects a val depending on a children val to a child val.
  # This is called by childAdded on the new parent of the childMorph
  # that has just been added
  connectToChildVal: (valDependingOnChildrenVal, childVal) ->

    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      console.log "connecting " + valDependingOnChildrenVal.valName + " in morph "+ valDependingOnChildrenVal.ownerMorph.uniqueIDString() + " to receive input from " + childVal.valName + " in morph "+ childVal.ownerMorph.uniqueIDString()

    # check whether you are reconnecting
    # an arg that was temporarily
    # disconnected
    #if @morphContainingTheseArgs.constructor.name == "RectangleMorph"
    #  debugger
    argumentToBeConnected = @tryToReconnectDisconnectedArgFirst childVal
    argumentToBeConnected ?= new Arg childVal, valDependingOnChildrenVal
    argumentToBeConnected.fromChild = true
    @childrenArgByName[childVal.valName] ?= {}
    @childrenArgByName[childVal.valName][childVal.id] = argumentToBeConnected
    @childrenArgByNameCount[childVal.valName]?= 0
    @childrenArgByNameCount[childVal.valName]++
    if childVal.directlyOrIndirectlyDependsOnAParentVal
      @valContainingTheseArgs.stainValCalculatedFromParent(childVal)
    argumentToBeConnected.args.argFromChildMightHaveChanged childVal

  # connects a val depending on a parent val to a parent val.
  # This is called by childAdded on the childMorph that has just
  # been added
  connectToParentVal: (valDependingOnParentVal, parentVal) ->
    # check whether you are reconnecting
    # an arg that was temporarily
    # disconnected
    argumentToBeConnected = @tryToReconnectDisconnectedArgFirst childVal
    argumentToBeConnected ?= new Arg childVal, valDependingOnParentVal
    argumentToBeConnected.directlyCalculatedFromParent = true
    argumentToBeConnected.turnIntoArgDirectlyOrIndirectlyDependingOnParent()

  ################################################
  #  handling update of argument coming from
  #  other values
  ################################################

  argFromChildMightHaveChanged: (childValThatMightHaveChanged) ->

    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      console.log "marking child value " + childValThatMightHaveChanged.valName + " in morph "+ childValThatMightHaveChanged.ownerMorph.uniqueIDString() + " as \"might have changed\" "


    arg = @argById[childValThatMightHaveChanged.id]
    if  !arg?  or  @holdOffFromPropagatingChanges then return
    if arg.markedForRemoval then return
    # the unique identifier of a val is given by
    # its name as a string and the id of the Morph it belongs to
    if arg.maybeChangedSinceLastCalculation and childValThatMightHaveChanged.ownerMorph.parent == @morphContainingTheseArgs
      arg.checkBasedOnSignature()
    else if arg.maybeChangedSinceLastCalculation and childValThatMightHaveChanged.ownerMorph.parent != @morphContainingTheseArgs
      # argsMaybeChangedSinceLastCalculation contains kid and kid not child anymore
      arg.break()
    else if !arg.maybeChangedSinceLastCalculation and childValThatMightHaveChanged.ownerMorph.parent == @morphContainingTheseArgs
      # argsMaybeChangedSinceLastCalculation not contains kid and kid is now child
      # ???
      add the data structures and mark it as dirty and signature undefined
    else if !arg.maybeChangedSinceLastCalculation and childValThatMightHaveChanged.ownerMorph.parent != @morphContainingTheseArgs
      # argsMaybeChangedSinceLastCalculation not contains kid and not child
      # ???
      this should never happen
    if !@valContainingTheseArgs.directlyOrIndirectlyDependsOnAParentVal
      @valContainingTheseArgs.checkAndPropagateChangeBasedOnArgChange()

  ################################################
  #  fetching correct arguments values
  ################################################

  # all @calculatedDirectlyOfIndirectlyFromParentById
  # always need
  # to be fetched (maybe recalculated)
  # regardless of their dirty val
  # we then update the signature and heal them.
  # Note that some children args can be in this set
  # as children args can maybe depend directly
  # or indirectly from parent vals.
  fetchAllArgsDirectlyOrIndirectlyCalculatedFromParent: ->
    oneOrMoreArgsHaveActuallyChanged = false
    for idNotUsed, argCalculatedFromParent of @calculatedDirectlyOfIndirectlyFromParentById
      # check that the child/parent arg we are going to fetch
      # is still a in a child/parent relationship with
      # this morph. If not, this check will remove the
      # arg and just move on
      if argCalculatedFromParent.removeArgIfMarkedForRemoval()
        continue
      # note here that since in @argValsById we keep the
      # reference to the Val object, which is the one
      # we pass to the "functionToRecalculate", we
      # don't need to put the fetched val anywhere.
      argCalculatedFromParent.fetchVal()
      # updateSignatureAndHeal returns true if
      # the argument has actually changed since last
      # recalculation
      oneOrMoreArgsHaveActuallyChanged = oneOrMoreArgsHaveActuallyChanged or argCalculatedFromParent.updateSignatureAndHeal()
    return oneOrMoreArgsHaveActuallyChanged

  fetchAllRemainingArgsNeedingRecalculation: ->
    @holdOffFromPropagatingChanges = true

    oneOrMoreArgsHaveActuallyChanged = false
    for maybeModifiedArgId of @argsMaybeChangedSinceLastCalculationById
      maybeModifiedArg = @argById[maybeModifiedArgId]
      # check that the child arg we are going to fetch
      # is still a in a child relationship with
      # this morph. If not, this check will remove the
      # arg and just move on.
      if maybeModifiedArg.removeArgIfMarkedForRemoval()
        continue
      # note here that since in @argValsById we keep the
      # reference to the Val object, which is the one
      # we pass to the "functionToRecalculate", we
      # don't need to put the fetched val anywhere.

      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "fetching potentially changed input: " + maybeModifiedArg.id

      debugger
      maybeModifiedArg.fetchVal()
      # the argument has actually changed since last
      # recalculation
      oneOrMoreArgsHaveActuallyChanged = oneOrMoreArgsHaveActuallyChanged or maybeModifiedArg.updateSignature()
    return oneOrMoreArgsHaveActuallyChanged

    # since we calculated all the damaged args,
    # heal them all
    @args.healAll()
    @holdOffFromPropagatingChanges = false
  @coffeeScriptSourceOfThisClass: '''
# Args are the input based on which a val is calculated
# There are several pieces of "aggregate" information that
# we keep about args considered together e.g. whether
# any of them has changed since the last calculation of the
# Val, or which ones directly or indirectly depend on a Parent
# Val.

# REQUIRES ProfilerData

class Args
  # some accessors gere to get to the
  # actual arguments. You can get to all
  # of them by Id of the Value
  # or, in the care of an argument connected
  # to a parent morph, by the value name
  # (since there is only one Arg connected
  # to the parent for each value name, which is
  # not the case for children Args as
  # onviously you may have many children and hence
  # many arguments)
  argById: null
  parentArgByName: null
  childrenArgByName: null
  # we want to group together all children
  # values under the same name
  # so we keep this count separate
  # rather than counting navigating the keys
  childrenArgByNameCount: null
  localArgByName: null
  calculatedDirectlyOfIndirectlyFromParentById: null
  calculatedDirectlyOfIndirectlyFromParentByIdCount: 0

  countOfDamaged: 0
  morphContainingTheseArgs: null

  # just some flags to keep track of which
  # args might have changed. Again, we might
  # not know for sure because we don't necessarily
  # recalculate them
  argsMaybeChangedSinceLastCalculationById: null

  constructor: (@valContainingTheseArgs) ->
    @argById = {}
    @parentArgByName = {}
    @childrenArgByName = {}
    @childrenArgByNameCount = {}
    @localArgByName = {}
    @calculatedDirectlyOfIndirectlyFromParentById = {}
    @argsMaybeChangedSinceLastCalculationById = {}

    @morphContainingTheseArgs = @valContainingTheseArgs.ownerMorph


  ################################################
  #  breaking / healing
  ################################################

  healAll: () ->
    for eachArg of argsMaybeChangedSinceLastCalculationById
      eachArg.heal()


  ################################################
  #  accessors
  ################################################

  getByVal: (theVal) ->
    return @getById theVal.id

  ################################################
  #  setup methods - these are called in the
  #  constructors of each value to prepare
  #  for the arguments.
  ################################################

  # for local arguments, you can
  # actually create the arguments as they are static
  setup_AddAllLocalArgVals: (localInputVals) ->
    for each in localInputVals
      # connecting arguments that come from local values is
      # easier because those links are static, they are done
      # at construction time once and for all
      each.localValsAffectedByChangeOfThisVal.push @valContainingTheseArgs
      newArg = new Arg localInputVals, @valContainingTheseArgs
      newArg.fromLocal = true
      @localArgByName[localInputVals.valueName] = newArg

  # you can't create the actual arguments yet as these
  # arguments will be connected dynamically. we just prepare
  # some a structure in the morph so we'll be able
  # to connect the actual values in the morph's
  # childAdded and childRemoved methods
  setup_AddAllParentArgNames: (parentArgsNames) ->
    # ORIGINAL CODE:
    #for each var in parentArgsNames
    #  if !@ownerMorph.morphValsDirectlyDependingOnParentVals[each]?
    #    @ownerMorph.morphValsDirectlyDependingOnParentVals[each] = {}
    #  @ownerMorph.morphValsDirectlyDependingOnParentVals[each][@valName] = @

    for eachVar in parentArgsNames
      @morphContainingTheseArgs.morphValsDirectlyDependingOnParentVals[eachVar]?= {}
      @morphContainingTheseArgs.morphValsDirectlyDependingOnParentVals[eachVar][@valContainingTheseArgs.valName] = @valContainingTheseArgs

  # you can't create the actual arguments yet as these
  # arguments will be connected dynamically. we just prepare
  # some a structure in the morph so we'll be able
  # to connect the actual values in the morph's
  # childAdded and childRemoved methods
  setup_AddAllChildrenArgNames: (childrenArgsNames) ->
    #debugger
    for eachVar in childrenArgsNames
      @morphContainingTheseArgs.morphValsDependingOnChildrenVals[eachVar] ?= {}
      @morphContainingTheseArgs.morphValsDependingOnChildrenVals[eachVar][@valContainingTheseArgs.valName] = @valContainingTheseArgs

  ################################################
  #  argument connenction methods
  #  these are called when Morphs are moved
  #  around so we need to connect/disconnect
  #  the arguments of each value to/from the
  #  (new) parent/children
  ################################################

  # check whether you are reconnecting
  # an arg that was temporarily
  # disconnected
  tryToReconnectDisconnectedArgFirst: (parentOrChildVal) ->
    existingArg = @argById[parentOrChildVal.id]
    if existingArg?
      existingArg.markedForRemoval = false
      existingArg.valContainingThisArg.argMightHaveChanged(parentOrChildVal)
      return existingArg
    return null


  # connects a val depending on a children val to a child val.
  # This is called by childAdded on the new parent of the childMorph
  # that has just been added
  connectToChildVal: (valDependingOnChildrenVal, childVal) ->

    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      console.log "connecting " + valDependingOnChildrenVal.valName + " in morph "+ valDependingOnChildrenVal.ownerMorph.uniqueIDString() + " to receive input from " + childVal.valName + " in morph "+ childVal.ownerMorph.uniqueIDString()

    # check whether you are reconnecting
    # an arg that was temporarily
    # disconnected
    #if @morphContainingTheseArgs.constructor.name == "RectangleMorph"
    #  debugger
    argumentToBeConnected = @tryToReconnectDisconnectedArgFirst childVal
    argumentToBeConnected ?= new Arg childVal, valDependingOnChildrenVal
    argumentToBeConnected.fromChild = true
    @childrenArgByName[childVal.valName] ?= {}
    @childrenArgByName[childVal.valName][childVal.id] = argumentToBeConnected
    @childrenArgByNameCount[childVal.valName]?= 0
    @childrenArgByNameCount[childVal.valName]++
    if childVal.directlyOrIndirectlyDependsOnAParentVal
      @valContainingTheseArgs.stainValCalculatedFromParent(childVal)
    argumentToBeConnected.args.argFromChildMightHaveChanged childVal

  # connects a val depending on a parent val to a parent val.
  # This is called by childAdded on the childMorph that has just
  # been added
  connectToParentVal: (valDependingOnParentVal, parentVal) ->
    # check whether you are reconnecting
    # an arg that was temporarily
    # disconnected
    argumentToBeConnected = @tryToReconnectDisconnectedArgFirst childVal
    argumentToBeConnected ?= new Arg childVal, valDependingOnParentVal
    argumentToBeConnected.directlyCalculatedFromParent = true
    argumentToBeConnected.turnIntoArgDirectlyOrIndirectlyDependingOnParent()

  ################################################
  #  handling update of argument coming from
  #  other values
  ################################################

  argFromChildMightHaveChanged: (childValThatMightHaveChanged) ->

    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      console.log "marking child value " + childValThatMightHaveChanged.valName + " in morph "+ childValThatMightHaveChanged.ownerMorph.uniqueIDString() + " as \"might have changed\" "


    arg = @argById[childValThatMightHaveChanged.id]
    if  !arg?  or  @holdOffFromPropagatingChanges then return
    if arg.markedForRemoval then return
    # the unique identifier of a val is given by
    # its name as a string and the id of the Morph it belongs to
    if arg.maybeChangedSinceLastCalculation and childValThatMightHaveChanged.ownerMorph.parent == @morphContainingTheseArgs
      arg.checkBasedOnSignature()
    else if arg.maybeChangedSinceLastCalculation and childValThatMightHaveChanged.ownerMorph.parent != @morphContainingTheseArgs
      # argsMaybeChangedSinceLastCalculation contains kid and kid not child anymore
      arg.break()
    else if !arg.maybeChangedSinceLastCalculation and childValThatMightHaveChanged.ownerMorph.parent == @morphContainingTheseArgs
      # argsMaybeChangedSinceLastCalculation not contains kid and kid is now child
      # ???
      add the data structures and mark it as dirty and signature undefined
    else if !arg.maybeChangedSinceLastCalculation and childValThatMightHaveChanged.ownerMorph.parent != @morphContainingTheseArgs
      # argsMaybeChangedSinceLastCalculation not contains kid and not child
      # ???
      this should never happen
    if !@valContainingTheseArgs.directlyOrIndirectlyDependsOnAParentVal
      @valContainingTheseArgs.checkAndPropagateChangeBasedOnArgChange()

  ################################################
  #  fetching correct arguments values
  ################################################

  # all @calculatedDirectlyOfIndirectlyFromParentById
  # always need
  # to be fetched (maybe recalculated)
  # regardless of their dirty val
  # we then update the signature and heal them.
  # Note that some children args can be in this set
  # as children args can maybe depend directly
  # or indirectly from parent vals.
  fetchAllArgsDirectlyOrIndirectlyCalculatedFromParent: ->
    oneOrMoreArgsHaveActuallyChanged = false
    for idNotUsed, argCalculatedFromParent of @calculatedDirectlyOfIndirectlyFromParentById
      # check that the child/parent arg we are going to fetch
      # is still a in a child/parent relationship with
      # this morph. If not, this check will remove the
      # arg and just move on
      if argCalculatedFromParent.removeArgIfMarkedForRemoval()
        continue
      # note here that since in @argValsById we keep the
      # reference to the Val object, which is the one
      # we pass to the "functionToRecalculate", we
      # don't need to put the fetched val anywhere.
      argCalculatedFromParent.fetchVal()
      # updateSignatureAndHeal returns true if
      # the argument has actually changed since last
      # recalculation
      oneOrMoreArgsHaveActuallyChanged = oneOrMoreArgsHaveActuallyChanged or argCalculatedFromParent.updateSignatureAndHeal()
    return oneOrMoreArgsHaveActuallyChanged

  fetchAllRemainingArgsNeedingRecalculation: ->
    @holdOffFromPropagatingChanges = true

    oneOrMoreArgsHaveActuallyChanged = false
    for maybeModifiedArgId of @argsMaybeChangedSinceLastCalculationById
      maybeModifiedArg = @argById[maybeModifiedArgId]
      # check that the child arg we are going to fetch
      # is still a in a child relationship with
      # this morph. If not, this check will remove the
      # arg and just move on.
      if maybeModifiedArg.removeArgIfMarkedForRemoval()
        continue
      # note here that since in @argValsById we keep the
      # reference to the Val object, which is the one
      # we pass to the "functionToRecalculate", we
      # don't need to put the fetched val anywhere.

      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "fetching potentially changed input: " + maybeModifiedArg.id

      debugger
      maybeModifiedArg.fetchVal()
      # the argument has actually changed since last
      # recalculation
      oneOrMoreArgsHaveActuallyChanged = oneOrMoreArgsHaveActuallyChanged or maybeModifiedArg.updateSignature()
    return oneOrMoreArgsHaveActuallyChanged

    # since we calculated all the damaged args,
    # heal them all
    @args.healAll()
    @holdOffFromPropagatingChanges = false  '''

# just a draft, it's not meant to compile or work
# just yet, we are just assembling things

# a GroundVal holds a val that is not
# calculated from anything: it's actually
# changeable as is. It doesn't react to the
# change of any other Val.

# REQUIRES ProfilerData

class GroundVal
  
  directlyOrIndirectlyDependsOnAParentVal: false

  # we use "lastCalculatedValContent" here just as a matter of
  # uniformity. The cached val of a GroundVal
  # is always up to date, it's always good for use.
  lastCalculatedValContent: null

  # always false for GroundVals, because there is never
  # a recalculation to be done here, the val is always
  # exactly known
  lastCalculatedValContentMaybeOutdated: false
  # these vals are affected by change of this
  # val
  localValsAffectedByChangeOfThisVal: null

  args: null

  constructor: (@valName, @lastCalculatedValContent, @ownerMorph) ->

    # stuff to do only if we are building GroundVal and not
    # any of its subclasses
    if @constructor.name == "GroundVal" and
        WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode

      ProfilerData.reactiveValues_createdGroundVals++

      if !@lastCalculatedValContent?
        contentOfLastCalculatedVal = null
      else
        contentOfLastCalculatedVal = @lastCalculatedValContent

      console.log "building GroundVal named " + @valName + " in morph "+ @ownerMorph.uniqueIDString() + " with content: " + contentOfLastCalculatedVal

    @addMyselfToMorphsValsList valName
    @id = @valName + @ownerMorph.uniqueIDString()
    @localValsAffectedByChangeOfThisVal = []


  checkAndPropagateChangeBasedOnArgChange: () ->
    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      console.log "checking if " + @valName + " in morph "+ @ownerMorph.uniqueIDString() + " has any damaged inputs..."

    # we can check these with a counter, DON'T do
    # something like Object.keys(obj).length because it's
    # unnecessary overhead.
    # Note here that there is no propagation in case:
    #  a) there is a change but we already notified our
    #     change to the connected vals
    #  b) there is no change and we never notified
    #     any change to the connected vals
    if @args.countOfDamaged > 0
      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "... " + @valName  + " in morph "+ @ownerMorph.uniqueIDString() + " has some damaged inputs but it's already broken so nothing to do"
      if @lastCalculatedValContentMaybeOutdated == false
        if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
          console.log "... " + @valName  + " in morph "+ @ownerMorph.uniqueIDString() + " has some damaged inputs and wasn't damaged so need to propagate damage"
        @lastCalculatedValContentMaybeOutdated = true
        @notifyDependentParentOrLocalValsOfPotentialChange()
    else # there are NO damanged args
      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "... " + @valName  + " in morph "+ @ownerMorph.uniqueIDString() + " has NO damaged inputs"
      @heal()


  heal: ->
    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      console.log "... now healing " + @id

    if @lastCalculatedValContentMaybeOutdated
      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "... " + @id + "'s last calculated value was marked as broken, notifying dep values of this being healed"
      @lastCalculatedValContentMaybeOutdated = false
      @notifyDependentParentOrLocalValsOfPotentialChange()


  addMyselfToMorphsValsList: (valName) ->
    @ownerMorph.allValsInMorphByName[valName] = @

  stainValCalculatedFromParent: (stainingArgVal) ->
    # note that staining argument here could
    # be a child argument, as it might directly or
    # indirectly depend on
    # a value which is in a parent
    stainingArg = @args.getByVal stainingArgVal
    # this might recursively stain other values
    # depending on this value
    stainingArg.turnIntoArgDirectlyOrIndirectlyDependingOnParent()

  unstainValCalculatedFromParent: (unstainedArgVal) ->
    # note that argument here could
    # be a child argument, as it might directly or
    # indirectly depend on
    # a value which is in a parent
    unstainedArg = @args.getByVal unstainedArgVal
    # this might recursively un-stain other values
    # depending on this value
    stainingArg.turnIntoArgNotDirectlyNorIndirectlyDependingOnParent()


  # this is the only type of val that we
  # can actually change directly.
  # All other typed of vals are calculated
  # from other vals.
  setVal: (newVal) ->
    @signature = newVal.signature

    # comparison needs to be smarter?
    # does this need to have multiple version for basic vals
    # like integers and strings?
    if @lastCalculatedValContent == newVal
      return
    else
      @lastCalculatedValContent = newVal
      @notifyDependentParentOrLocalValsOfPotentialChange()
  
  # note that parents never notify children
  # of any change, because we don't want this
  # operation to take long as there might be hundreds
  # of children directly/indirectly under this morph.
  notifyDependentParentOrLocalValsOfPotentialChange: ->
    for cv in @localValsAffectedByChangeOfThisVal
      cv.argMightHaveChanged @
    if @ownerMorph.parent?
      v = @ownerMorph.parent.morphValsDependingOnChildrenVals[@valName]
      for k of v
        #k.argFromChildMightHaveChanged @
        k.argMightHaveChanged @

  # no logic for recalculation needed
  # fetchVal is an apt name because it doesn't necessarily
  # recalculate the val (although it might need to) and it
  # doesn't just look it up either. It's some sort of retrieval.
  fetchVal: ->
    return @lastCalculatedValContent



  @coffeeScriptSourceOfThisClass: '''
# just a draft, it's not meant to compile or work
# just yet, we are just assembling things

# a GroundVal holds a val that is not
# calculated from anything: it's actually
# changeable as is. It doesn't react to the
# change of any other Val.

# REQUIRES ProfilerData

class GroundVal
  
  directlyOrIndirectlyDependsOnAParentVal: false

  # we use "lastCalculatedValContent" here just as a matter of
  # uniformity. The cached val of a GroundVal
  # is always up to date, it's always good for use.
  lastCalculatedValContent: null

  # always false for GroundVals, because there is never
  # a recalculation to be done here, the val is always
  # exactly known
  lastCalculatedValContentMaybeOutdated: false
  # these vals are affected by change of this
  # val
  localValsAffectedByChangeOfThisVal: null

  args: null

  constructor: (@valName, @lastCalculatedValContent, @ownerMorph) ->

    # stuff to do only if we are building GroundVal and not
    # any of its subclasses
    if @constructor.name == "GroundVal" and
        WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode

      ProfilerData.reactiveValues_createdGroundVals++

      if !@lastCalculatedValContent?
        contentOfLastCalculatedVal = null
      else
        contentOfLastCalculatedVal = @lastCalculatedValContent

      console.log "building GroundVal named " + @valName + " in morph "+ @ownerMorph.uniqueIDString() + " with content: " + contentOfLastCalculatedVal

    @addMyselfToMorphsValsList valName
    @id = @valName + @ownerMorph.uniqueIDString()
    @localValsAffectedByChangeOfThisVal = []


  checkAndPropagateChangeBasedOnArgChange: () ->
    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      console.log "checking if " + @valName + " in morph "+ @ownerMorph.uniqueIDString() + " has any damaged inputs..."

    # we can check these with a counter, DON'T do
    # something like Object.keys(obj).length because it's
    # unnecessary overhead.
    # Note here that there is no propagation in case:
    #  a) there is a change but we already notified our
    #     change to the connected vals
    #  b) there is no change and we never notified
    #     any change to the connected vals
    if @args.countOfDamaged > 0
      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "... " + @valName  + " in morph "+ @ownerMorph.uniqueIDString() + " has some damaged inputs but it's already broken so nothing to do"
      if @lastCalculatedValContentMaybeOutdated == false
        if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
          console.log "... " + @valName  + " in morph "+ @ownerMorph.uniqueIDString() + " has some damaged inputs and wasn't damaged so need to propagate damage"
        @lastCalculatedValContentMaybeOutdated = true
        @notifyDependentParentOrLocalValsOfPotentialChange()
    else # there are NO damanged args
      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "... " + @valName  + " in morph "+ @ownerMorph.uniqueIDString() + " has NO damaged inputs"
      @heal()


  heal: ->
    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      console.log "... now healing " + @id

    if @lastCalculatedValContentMaybeOutdated
      if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
        console.log "... " + @id + "'s last calculated value was marked as broken, notifying dep values of this being healed"
      @lastCalculatedValContentMaybeOutdated = false
      @notifyDependentParentOrLocalValsOfPotentialChange()


  addMyselfToMorphsValsList: (valName) ->
    @ownerMorph.allValsInMorphByName[valName] = @

  stainValCalculatedFromParent: (stainingArgVal) ->
    # note that staining argument here could
    # be a child argument, as it might directly or
    # indirectly depend on
    # a value which is in a parent
    stainingArg = @args.getByVal stainingArgVal
    # this might recursively stain other values
    # depending on this value
    stainingArg.turnIntoArgDirectlyOrIndirectlyDependingOnParent()

  unstainValCalculatedFromParent: (unstainedArgVal) ->
    # note that argument here could
    # be a child argument, as it might directly or
    # indirectly depend on
    # a value which is in a parent
    unstainedArg = @args.getByVal unstainedArgVal
    # this might recursively un-stain other values
    # depending on this value
    stainingArg.turnIntoArgNotDirectlyNorIndirectlyDependingOnParent()


  # this is the only type of val that we
  # can actually change directly.
  # All other typed of vals are calculated
  # from other vals.
  setVal: (newVal) ->
    @signature = newVal.signature

    # comparison needs to be smarter?
    # does this need to have multiple version for basic vals
    # like integers and strings?
    if @lastCalculatedValContent == newVal
      return
    else
      @lastCalculatedValContent = newVal
      @notifyDependentParentOrLocalValsOfPotentialChange()
  
  # note that parents never notify children
  # of any change, because we don't want this
  # operation to take long as there might be hundreds
  # of children directly/indirectly under this morph.
  notifyDependentParentOrLocalValsOfPotentialChange: ->
    for cv in @localValsAffectedByChangeOfThisVal
      cv.argMightHaveChanged @
    if @ownerMorph.parent?
      v = @ownerMorph.parent.morphValsDependingOnChildrenVals[@valName]
      for k of v
        #k.argFromChildMightHaveChanged @
        k.argMightHaveChanged @

  # no logic for recalculation needed
  # fetchVal is an apt name because it doesn't necessarily
  # recalculate the val (although it might need to) and it
  # doesn't just look it up either. It's some sort of retrieval.
  fetchVal: ->
    return @lastCalculatedValContent


  '''

# just a draft, it's not meant to compile or work
# just yet, we are just assembling things

# REQUIRES ProfilerData

class BasicCalculatedVal extends GroundVal
  # sometimes we know that the cached val
  # might be out of date but we don't want to
  # trigger a recalculation to actually check.
  # This is what this flag tracks.
  # Note that this flag has no meaning if this Val
  # is @directlyOrIndirectlyDependsOnAParentVal, as in that case
  # we always have to fetch the val rather than
  # hope to have a good cached version.
  lastCalculatedValContentMaybeOutdated: true
  lastCalculatedValContent: undefined
  # this is needed because during the recalculation step
  # we don't want to process the notifications that
  # we receive about our args changing, that
  # would be messy and wasteful.
  holdOffFromPropagatingChanges: false

  # this val might be referenced by parent Morph or
  # children Morphs dynamically so they way to find this
  # val might be through the name as a string
  constructor: (@valName, @functionToRecalculate, @localInputVals, parentArgsNames, childrenArgsNames, @ownerMorph) ->
    super(@valName, null, @ownerMorph)

    ProfilerData.reactiveValues_createdBasicCalculatedValues++

    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      collectionOfChildrenValuesNames = ""
      for eachName in childrenArgsNames
        collectionOfChildrenValuesNames = collectionOfChildrenValuesNames + ", " + eachName
      console.log "building BasicCalculatedVal named " + @valName + " in morph "+ @ownerMorph.uniqueIDString() + " depending on children variables: " + collectionOfChildrenValuesNames
    
    # we don't mark immediately this value as
    # depending on parent, the reason is that there might be
    # no parent morph to this one, so in some circumstances
    # this value's content can actually just be treated as
    # a normal value that doesn't need to automatically
    # fetch values for some of its arguments, and which
    # notification of changes can actually be believed.
    # As soon as a parent Morph is added, then this doesn't
    # hold true anymore - this Value stops notifying the
    # other dependent values of changes because it doesn't
    # get the changes from the parent values itself...
    #@directlyOrIndirectlyDependsOnAParentVal = true

    @args = new Args(@)
    @args.setup_AddAllLocalArgVals @localInputVals
    @args.setup_AddAllParentArgNames parentArgsNames
    @args.setup_AddAllChildrenArgNames childrenArgsNames


  # Given that this Val if a pure function depending
  # on some args, we want to know at all times
  # whether the args change. If the don't, then we
  # know that there is no need to recalculate the present
  # val. So this method is used by all the args
  # of this val to notify whether they have changed
  # or not.
  # It's important to note that this method can be
  # called for two reasons:
  # 1) an arg has just been recalculated. Hence
  #    we know exactly its val
  # 2) an arg has just maybe changed because
  #    he knows that one of HIS args has changed
  #    but since we want to minimise recalculations we
  #    don't know what the new val is, just that
  #    maybe it has changed. 
  # There is one exception: all args
  # that depend on a parent val (directly or indirectly)
  # never notify anybody. This is because if a parent had
  # to notify all the directlty or indirectly connected
  # vals, in general it could be
  # very expensive, as for example there could be 50
  # children to notify (and they might to notify other
  # connected vals). What happens instead is that when
  # this val is calculated, all args that depend on
  # a parent (directly or indirectly) are
  # always re-fetched, we just
  # can't trust them to have notified us of their change...
  # this method never triggers a recalculation!
  # we could receive this because
  #   - a recalculation has happened down the line
  #     and we know the actual val of the
  #     changed arg
  #   - some invalidation has happened down the line
  #     and hence the arg *might* have changed
  #     but we don't know the actual val.
  # We just need to keep track of which args might
  # need recalculation and which ones are surely the
  # same as the version we used for our last calculation.
  #argMightHaveChanged: (changedArgVal) ->
  #
  #  if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
  #    console.log "marking argument " + changedArgVal.valName + " connected to morph " + changedArgVal.ownerMorph.uniqueIDString() + " as \"might have changed\" "
  #
  #  changedArg = @args.argById[changedArgVal.id]
  #  if changedArg.markedForRemoval or @holdOffFromPropagatingChanges then return
  #  changedArg.checkBasedOnSignature()
  #  if !@directlyOrIndirectlyDependsOnAParentVal
  #    @checkAndPropagateChangeBasedOnArgChange()



  propagateChangeOfThisValIfNeeded: (newValContent) ->
    debugger
    if newValContent.signature == @lastCalculatedValContent.signature
      @heal()
    else # newValContent.signature != @lastCalculatedValContent.signature
      if @lastCalculatedValContentMaybeOutdated == false
        notifyDependentParentOrLocalValsOfPotentialChange()
        # note that @lastCalculatedValContentMaybeOutdated
        # remains false because we are sure of this value
        # as we just calculated

  # this method is called either by the user/system
  # because it's time to get the val, or it's
  # called by another val which is being asked to
  # return its val recursively.
  # this method could trigger a recalculation of some
  # args, and of this val itself (obviously
  # this whole apparatus is to minimise recalculations).
  # Even if this
  # particular function *might* be cheap to compute,
  # the "dirty" parameters of its input might not be cheap
  # to calculate.
  # fetchVal is an apt name because it doesn't necessarily
  # recalculate the val (although it might need to) and it
  # doesn't just look it up either. It's some sort of retrieval.
  fetchVal: () ->
    if @lastCalculatedValContentMaybeOutdated is false
      return @lastCalculatedValContent
    
    oneOrMoreArgsHaveActuallyChanged = false
    oneOrMoreArgsHaveActuallyChanged = oneOrMoreArgsHaveActuallyChanged or @args.fetchAllArgsDirectlyOrIndirectlyCalculatedFromParent()
    oneOrMoreArgsHaveActuallyChanged = oneOrMoreArgsHaveActuallyChanged or @args.fetchAllRemainingArgsNeedingRecalculation()

    if oneOrMoreArgsHaveActuallyChanged      
      # functionToRecalculate must always return
      # an object with a calculated default signature
      # in the .signature property
      newValContent =
        @functionToRecalculate \
          @args.argById,
          @args.localArgByName,
          @args.parentArgByName,
          @args.childrenArgByName,
          @args.childrenArgByNameCount

      @signature = newValContent.signature
      @lastCalculatedValContent = newValContent
      if !@directlyOrIndirectlyDependsOnAParentVal
        @propagateChangeOfThisValIfNeeded newValContent
    return @lastCalculatedValContent
      
    


  @coffeeScriptSourceOfThisClass: '''
# just a draft, it's not meant to compile or work
# just yet, we are just assembling things

# REQUIRES ProfilerData

class BasicCalculatedVal extends GroundVal
  # sometimes we know that the cached val
  # might be out of date but we don't want to
  # trigger a recalculation to actually check.
  # This is what this flag tracks.
  # Note that this flag has no meaning if this Val
  # is @directlyOrIndirectlyDependsOnAParentVal, as in that case
  # we always have to fetch the val rather than
  # hope to have a good cached version.
  lastCalculatedValContentMaybeOutdated: true
  lastCalculatedValContent: undefined
  # this is needed because during the recalculation step
  # we don't want to process the notifications that
  # we receive about our args changing, that
  # would be messy and wasteful.
  holdOffFromPropagatingChanges: false

  # this val might be referenced by parent Morph or
  # children Morphs dynamically so they way to find this
  # val might be through the name as a string
  constructor: (@valName, @functionToRecalculate, @localInputVals, parentArgsNames, childrenArgsNames, @ownerMorph) ->
    super(@valName, null, @ownerMorph)

    ProfilerData.reactiveValues_createdBasicCalculatedValues++

    if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
      collectionOfChildrenValuesNames = ""
      for eachName in childrenArgsNames
        collectionOfChildrenValuesNames = collectionOfChildrenValuesNames + ", " + eachName
      console.log "building BasicCalculatedVal named " + @valName + " in morph "+ @ownerMorph.uniqueIDString() + " depending on children variables: " + collectionOfChildrenValuesNames
    
    # we don't mark immediately this value as
    # depending on parent, the reason is that there might be
    # no parent morph to this one, so in some circumstances
    # this value's content can actually just be treated as
    # a normal value that doesn't need to automatically
    # fetch values for some of its arguments, and which
    # notification of changes can actually be believed.
    # As soon as a parent Morph is added, then this doesn't
    # hold true anymore - this Value stops notifying the
    # other dependent values of changes because it doesn't
    # get the changes from the parent values itself...
    #@directlyOrIndirectlyDependsOnAParentVal = true

    @args = new Args(@)
    @args.setup_AddAllLocalArgVals @localInputVals
    @args.setup_AddAllParentArgNames parentArgsNames
    @args.setup_AddAllChildrenArgNames childrenArgsNames


  # Given that this Val if a pure function depending
  # on some args, we want to know at all times
  # whether the args change. If the don't, then we
  # know that there is no need to recalculate the present
  # val. So this method is used by all the args
  # of this val to notify whether they have changed
  # or not.
  # It's important to note that this method can be
  # called for two reasons:
  # 1) an arg has just been recalculated. Hence
  #    we know exactly its val
  # 2) an arg has just maybe changed because
  #    he knows that one of HIS args has changed
  #    but since we want to minimise recalculations we
  #    don't know what the new val is, just that
  #    maybe it has changed. 
  # There is one exception: all args
  # that depend on a parent val (directly or indirectly)
  # never notify anybody. This is because if a parent had
  # to notify all the directlty or indirectly connected
  # vals, in general it could be
  # very expensive, as for example there could be 50
  # children to notify (and they might to notify other
  # connected vals). What happens instead is that when
  # this val is calculated, all args that depend on
  # a parent (directly or indirectly) are
  # always re-fetched, we just
  # can't trust them to have notified us of their change...
  # this method never triggers a recalculation!
  # we could receive this because
  #   - a recalculation has happened down the line
  #     and we know the actual val of the
  #     changed arg
  #   - some invalidation has happened down the line
  #     and hence the arg *might* have changed
  #     but we don't know the actual val.
  # We just need to keep track of which args might
  # need recalculation and which ones are surely the
  # same as the version we used for our last calculation.
  #argMightHaveChanged: (changedArgVal) ->
  #
  #  if WorldMorph.preferencesAndSettings.printoutsReactiveValuesCode
  #    console.log "marking argument " + changedArgVal.valName + " connected to morph " + changedArgVal.ownerMorph.uniqueIDString() + " as \"might have changed\" "
  #
  #  changedArg = @args.argById[changedArgVal.id]
  #  if changedArg.markedForRemoval or @holdOffFromPropagatingChanges then return
  #  changedArg.checkBasedOnSignature()
  #  if !@directlyOrIndirectlyDependsOnAParentVal
  #    @checkAndPropagateChangeBasedOnArgChange()



  propagateChangeOfThisValIfNeeded: (newValContent) ->
    debugger
    if newValContent.signature == @lastCalculatedValContent.signature
      @heal()
    else # newValContent.signature != @lastCalculatedValContent.signature
      if @lastCalculatedValContentMaybeOutdated == false
        notifyDependentParentOrLocalValsOfPotentialChange()
        # note that @lastCalculatedValContentMaybeOutdated
        # remains false because we are sure of this value
        # as we just calculated

  # this method is called either by the user/system
  # because it's time to get the val, or it's
  # called by another val which is being asked to
  # return its val recursively.
  # this method could trigger a recalculation of some
  # args, and of this val itself (obviously
  # this whole apparatus is to minimise recalculations).
  # Even if this
  # particular function *might* be cheap to compute,
  # the "dirty" parameters of its input might not be cheap
  # to calculate.
  # fetchVal is an apt name because it doesn't necessarily
  # recalculate the val (although it might need to) and it
  # doesn't just look it up either. It's some sort of retrieval.
  fetchVal: () ->
    if @lastCalculatedValContentMaybeOutdated is false
      return @lastCalculatedValContent
    
    oneOrMoreArgsHaveActuallyChanged = false
    oneOrMoreArgsHaveActuallyChanged = oneOrMoreArgsHaveActuallyChanged or @args.fetchAllArgsDirectlyOrIndirectlyCalculatedFromParent()
    oneOrMoreArgsHaveActuallyChanged = oneOrMoreArgsHaveActuallyChanged or @args.fetchAllRemainingArgsNeedingRecalculation()

    if oneOrMoreArgsHaveActuallyChanged      
      # functionToRecalculate must always return
      # an object with a calculated default signature
      # in the .signature property
      newValContent =
        @functionToRecalculate \
          @args.argById,
          @args.localArgByName,
          @args.parentArgByName,
          @args.childrenArgByName,
          @args.childrenArgByNameCount

      @signature = newValContent.signature
      @lastCalculatedValContent = newValContent
      if !@directlyOrIndirectlyDependsOnAParentVal
        @propagateChangeOfThisValIfNeeded newValContent
    return @lastCalculatedValContent
      
    

  '''

# Global Functions ////////////////////////////////////////////////////


# This is used for mixins: MixedClassKeywords is used
# to protect some methods so the are not copied to object,
# because they have special meaning
# (this comment from a stackOverflow answer from clyde
# here: http://stackoverflow.com/a/8728164/1318347 )
MixedClassKeywords = ['onceAddedClassProperties', 'included']

arrayShallowCopy = (anArray) ->
  anArray.concat()

arrayShallowCopyAndReverse = (anArray) ->
  anArray.concat().reverse()

# This is used for testing purposes, we hash the
# data URL of a canvas object so to get a fingerprint
# of the image data, and compare it with "OK" pre-recorded
# values.
# adapted from http://werxltd.com/wp/2010/05/13/javascript-implementation-of-javas-string-hashcode-method/

hashCode = (stringToBeHashed) ->
  hash = 0
  return hash  if stringToBeHashed.length is 0
  for i in [0...stringToBeHashed.length]
    char = stringToBeHashed.charCodeAt(i)
    hash = ((hash << 5) - hash) + char
    hash = hash & hash # Convert to 32bit integer
  hash

# returns the function that does nothing
nop = ->
  # this is the function that does nothing:
  ->
    null

noOperation = ->
    null

isFunction = (functionToCheck) ->
  typeof(functionToCheck) is "function"

localize = (string) ->
  # override this function with custom localizations
  string

isNil = (thing) ->
  thing is `undefined` or thing is null

contains = (list, element) ->
  # answer true if element is a member of list
  list.some (any) ->
    any is element

detect = (list, predicate) ->
  # answer the first element of list for which predicate evaluates
  # true, otherwise answer null
  for element in list
    return element  if predicate.call(null, element)
  null

sizeOf = (object) ->
  # answer the number of own properties
  size = 0
  key = undefined
  for key of object
    size += 1  if Object.prototype.hasOwnProperty.call(object, key)
  size

isString = (target) ->
  typeof target is "string" or target instanceof String

isObject = (target) ->
  target? and (typeof target is "object" or target instanceof Object)

radians = (degrees) ->
  degrees * Math.PI / 180

degrees = (radians) ->
  radians * 180 / Math.PI

fontHeight = (height) ->
  minHeight = Math.max(height, WorldMorph.preferencesAndSettings.minimumFontHeight)
  minHeight * 1.2 # assuming 1/5 font size for ascenders

newCanvas = (extentPoint) ->
  # answer a new empty instance of Canvas, don't display anywhere
  ext = extentPoint or
    x: 0
    y: 0
  canvas = document.createElement("canvas")
  canvas.width = ext.x
  canvas.height = ext.y
  canvas

getMinimumFontHeight = ->
  # answer the height of the smallest font renderable in pixels
  str = "I"
  size = 50
  canvas = document.createElement("canvas")
  canvas.width = size
  canvas.height = size
  ctx = canvas.getContext("2d")
  ctx.font = "1px serif"
  maxX = ctx.measureText(str).width
  ctx.fillStyle = "black"
  ctx.textBaseline = "bottom"
  ctx.fillText str, 0, size
  for y in [0...size]
    for x in [0...maxX]
      data = ctx.getImageData(x, y, 1, 1)
      return size - y + 1  if data.data[3] isnt 0
  0


getBlurredShadowSupport = ->
  # check for Chrome issue 90001
  # http://code.google.com/p/chromium/issues/detail?id=90001
  source = document.createElement("canvas")
  source.width = 10
  source.height = 10
  ctx = source.getContext("2d")
  ctx.fillStyle = "rgb(255, 0, 0)"
  ctx.beginPath()
  ctx.arc 5, 5, 5, 0, Math.PI * 2, true
  ctx.closePath()
  ctx.fill()
  target = document.createElement("canvas")
  target.width = 10
  target.height = 10
  ctx = target.getContext("2d")
  ctx.shadowBlur = 10
  ctx.shadowColor = "rgba(0, 0, 255, 1)"
  ctx.drawImage source, 0, 0
  (if ctx.getImageData(0, 0, 1, 1).data[3] then true else false)

getDocumentPositionOf = (aDOMelement) ->
  # answer the absolute coordinates of a DOM element in the document
  if aDOMelement is null
    return (
      x: 0
      y: 0
    )
  pos =
    x: aDOMelement.offsetLeft
    y: aDOMelement.offsetTop

  offsetParent = aDOMelement.offsetParent
  while offsetParent?
    pos.x += offsetParent.offsetLeft
    pos.y += offsetParent.offsetTop
    if offsetParent isnt document.body and offsetParent isnt document.documentElement
      pos.x -= offsetParent.scrollLeft
      pos.y -= offsetParent.scrollTop
    offsetParent = offsetParent.offsetParent
  pos



# Morphic node class only cares about the
# parent/child connection between
# morphs. It's good to connect/disconnect
# morphs and to find parents or children
# who satisfy particular properties.
# OUT OF SCOPE:
# It's important to note that this layer
# knows nothing about visibility, targets,
# image buffers, dirty rectangles, events.
# Please no invokations to changed or fullChanged
# or updateRendering in here, and no
# touching of any of the out-of-scope properties
# mentioned.

class MorphicNode

  parent: null
  # "children" is an ordered list of the immediate
  # children of this node. First child is at the
  # back relative to other children, last child is at the
  # top.
  # This makes intuitive sense if you think for example
  # at a textMorph being added to a box morph: it is
  # added to the children list of the box morph, at the end,
  # and it's painted on top (otherwise it wouldn't be visible).
  # Note that when you add a morph A to a morph B, it doesn't
  # mean that A is cointained in B. The two potentially might
  # not even overlap.
  # The shadow is added as the first child, and it's
  # actually a special child that gets drawn before the
  # others.
  children: null

  constructor: (@parent = null, @children = []) ->
  
  
  # MorphicNode string representation: e.g. 'a MorphicNode[3]'
  toString: ->
    "a MorphicNode" + "[" + @children.length + "]"

  # currently unused in ZK
  childrenTopToBottom: ->
    arrayShallowCopyAndReverse(@children)  
  
  # MorphicNode accessing:
  addChild: (aMorphicNode) ->
    @children.push aMorphicNode
    aMorphicNode.parent = @
    @connectValuesToAddedChild aMorphicNode
  
  addChildFirst: (aMorphicNode) ->
    @children.splice 0, null, aMorphicNode
    aMorphicNode.parent = @
  
  removeChild: (aMorphicNode) ->
    idx = @children.indexOf(aMorphicNode)
    @children.splice idx, 1  if idx isnt -1
    aMorphicNode.parent = null
    @disconnectValuesFromRemovedChild aMorphicNode
  
  
  # MorphicNode functions:
  root: ->
    return @parent.root() if @parent?
    @
  
  # currently unused
  depth: ->
    return 0  unless @parent
    @parent.depth() + 1
  
  # Returns all the internal AND terminal nodes in the subtree starting
  # at this node - including this node.
  # Remember that the @children property already sorts morphs
  # from bottom to top

  allChildrenBottomToTop: ->
    result = [@] # includes myself
    @children.forEach (child) ->
      result = result.concat(child.allChildrenBottomToTop())
    result

  # the easiest way here would be to just return
  #   arrayShallowCopyAndReverse(@allChildrenBottomToTop())
  # but that's slower.
  # So we do the proper visit here instead.
  allChildrenTopToBottom: ->
    # base case - I am a leaf child, so I just
    # return an array with myself
    # note that I return an array rather than the
    # element cause this method is always expected
    # to return an array.
    if @children.length == 0
      return [@]

    # if I have some children instead, then let's create
    # an empty array where we'll concatenate the
    # others.
    arrayToReturn = []

    # if I have children, then start from the top
    # one (i.e. the last in the array) towards the bottom
    # one and concatenate their respective
    # top-to-bottom lists
    for morphNumber in [@children.length-1..0] by -1
      morph = @children[morphNumber]
      arrayToReturn = arrayToReturn.concat morph.allChildrenTopToBottom

    # ok, last we add ourselves to the bottom
    # of the list since this node is at the bottom of all of
    # its children...
    arrayToReturn.push @


  # A shorthand to run a function on all the internal/terminal nodes in the subtree
  # starting at this node - including this node.
  # Note that the function first runs on this node (which is the bottom-est morph)
  # and the proceeds by visiting the "bottom" child (first one in array)
  # and then all its children and then the second - bottomest child etc.
  # Also note that there is a more elegant implementation where
  # we just use @allChildrenBottomToTop() but that would mean to create
  # all the intermediary arrays with also all the unneeded node elements,
  # there is not need.
  forAllChildrenBottomToTop: (aFunction) ->
    aFunction.call null, @
    if @children.length
      @children.forEach (child) ->
        child.forAllChildrenBottomToTop aFunction
  
  # not used in ZK so far
  allLeafsBottomToTop: ->
    if @children.length == 0
      return [@]
    @children.forEach (child) ->
      result = result.concat(child.allLeafsBottomToTop())
    return result

  # Return all "parent" nodes from the root up to this node (including both)
  allParentsBottomToTop: ->
    if @parent?
      someParents = @parent.allParentsBottomToTop()
      someParents.push @
      return someParents
    else
      return [@]
  
  # Return all "parent" nodes from this node up to the root (including both)
  # Implementation commented-out below works but it's probably
  # slower than the one given, because concat is slower than pushing just
  # an array element, since concat does a shallow copy of both parts of
  # the array...
  #   allParentsTopToBottom: ->
  #    # includes myself
  #    result = [@]
  #    if @parent?
  #      result = result.concat(@parent.allParentsTopToBottom())
  #    result

  allParentsTopToBottom: ->
    return @allParentsBottomToTop().reverse()

  # this should be quicker than allParentsTopToBottomSuchThat
  # cause there are no concats making shallow copies.
  allParentsBottomToTopSuchThat: (predicate) ->
    result = []
    if @parent?
      result = @parent.allParentsBottomToTopSuchThat(predicate)
    if predicate.call(null, @)
      result.push @
    result

  allParentsTopToBottomSuchThat: (predicate) ->
    collected = []
    if predicate.call(null, @)
      collected = [@] # include myself
    if @parent?
      collected = collected.concat(@parent.allParentsTopToBottomSuchThat(predicate))
    return collected

  # quicker version that doesn't need us
  # to create any intermediate arrays
  # but rather just loops up the chain
  # and lets us return as soon as
  # we find a match
  containedInParentsOf: (morph) ->
    if !morph?
      # this happens when in a test, you select
      # a menu entry that doesn't exist.
      # so it's a good thing that we block the test
      # and let the user navigate through the world
      # to find the state of affairs that caused
      # the problem.
      console.log "failed to find morph in test: " + window.world.systemTestsRecorderAndPlayer.name
      console.log "trying to find item with text label: " +  window.world.systemTestsRecorderAndPlayer.testCommandsSequence[window.world.systemTestsRecorderAndPlayer.indexOfTestCommandBeingPlayedFromSequence].textLabelOfClickedItem
      console.log "...you can likely fix the test by correcting the label above in the test"
      debugger
    # test the morph itself
    if morph is @
      return true
    examinedMorph = morph
    while examinedMorph.parent?
      examinedMorph = examinedMorph.parent
      if examinedMorph is @
        return true
    return false

  # The direct children of the parent of this node. (current node not included)
  # never used in ZK
  # There is an alternative solution here below, in comment,
  # but I believe to be slower because it requires applying a function to
  # all the children. My version below just required an array copy, then
  # finding an element and splicing it out. I didn't test it so I don't
  # even know whether it works, but gut feeling...
  #  siblings: ->
  #    return []  unless @parent
  #    @parent.children.filter (child) =>
  #      child isnt @
  siblings: ->
    return []  unless @parent
    siblings = arrayShallowCopy @parent.children
    # now remove myself
    index = siblings.indexOf(@)
    siblings.splice(index, 1)
    return siblings

  # find how many siblings before me
  # satisfy a property
  # This is used when figuring out
  # how many buttons before a particular button
  # are labeled in the same way,
  # in the test system.
  # (so that we can say: automatically
  # click on the nth button labelled "X")
  howManySiblingsBeforeMeSuchThat: (predicate) ->
    theCount = 0
    for eachSibling in @parent.children
      if eachSibling == @
        return theCount
      if predicate.call(null, eachSibling)
        theCount++
    return theCount

  # find the nth child satisfying
  # a property.
  # This is used when finding
  # the nth buttons of a menu
  # having a particular label.
  # (so that we can say: automatically
  # click on the nth button labelled "X")
  nthChildSuchThat: (n, predicate) ->
    theCount = 0
    for eachChild in @children
      if predicate.call(null, eachChild)
        theCount++
        if theCount is n
          return eachChild
    return null
  
  # returns the first parent (going up from this node) that is of a particular class
  # (includes this particular node)
  # This is a subcase of "parentThatIsAnyOf".
  parentThatIsA: (constructor) ->
    # including myself
    return @ if @ instanceof constructor
    return null  unless @parent
    @parent.parentThatIsA constructor
  
  # returns the first parent (going up from this node) that belongs to a set
  # of classes. (includes this particular node).
  parentThatIsAnyOf: (constructors) ->
    # including myself
    constructors.forEach (each) =>
      if @constructor is each
        return @
    #
    return null  unless @parent
    @parent.parentThatIsAnyOf constructors

  # There is a simpler implementation that is also
  # slower where you first collect all the children
  # from top to bottom and then do the test on each
  # But this more efficient - we don't need to
  # create that entire list to start with, we just
  # navigate through the children arrays.
  topMorphSuchThat: (predicate) ->
    # base case - I am a leaf child, so I just test
    # the predicate on myself and return myself
    # if I satisfy, else I return null
    if @children.length == 0
      if predicate.call(null, @)
        return @
      else
        return null
    # if I have children, then start to test from
    # the top one (the last one in the array)
    # and proceed to test "towards the back" i.e.
    # testing elements of the array towards 0
    # If you find any morph satifies, the search is
    # over.
    for morphNumber in [@children.length-1..0] by -1
      morph = @children[morphNumber]
      foundMorph = morph.topMorphSuchThat(predicate)
      if foundMorph?
        return foundMorph
    # now that all children are tested, test myself
    if predicate.call(null, @)
      return @
    else
      return null
    # ok none of my children nor me test positive,
    # so return null.
    return null

  topmostChildSuchThat: (predicate) ->
    # start to test from
    # the top one (the last one in the array)
    # and proceed to test "towards the back" i.e.
    # testing elements of the array towards 0
    # If you find any child that satifies, the search is
    # over.
    for morphNumber in [@children.length-1..0] by -1
      morph = @children[morphNumber]
      if predicate.call(null, morph)
        return morph
    # ok none of my children test positive,
    # so return null.
    return null

  collectAllChildrenBottomToTopSuchThat: (predicate) ->
    collected = []
    if predicate.call(null, @)
      collected = [@] # include myself
    @children.forEach (child) ->
      collected = collected.concat(child.collectAllChildrenBottomToTopSuchThat(predicate))
    return collected

  @coffeeScriptSourceOfThisClass: '''
# Morphic node class only cares about the
# parent/child connection between
# morphs. It's good to connect/disconnect
# morphs and to find parents or children
# who satisfy particular properties.
# OUT OF SCOPE:
# It's important to note that this layer
# knows nothing about visibility, targets,
# image buffers, dirty rectangles, events.
# Please no invokations to changed or fullChanged
# or updateRendering in here, and no
# touching of any of the out-of-scope properties
# mentioned.

class MorphicNode

  parent: null
  # "children" is an ordered list of the immediate
  # children of this node. First child is at the
  # back relative to other children, last child is at the
  # top.
  # This makes intuitive sense if you think for example
  # at a textMorph being added to a box morph: it is
  # added to the children list of the box morph, at the end,
  # and it's painted on top (otherwise it wouldn't be visible).
  # Note that when you add a morph A to a morph B, it doesn't
  # mean that A is cointained in B. The two potentially might
  # not even overlap.
  # The shadow is added as the first child, and it's
  # actually a special child that gets drawn before the
  # others.
  children: null

  constructor: (@parent = null, @children = []) ->
  
  
  # MorphicNode string representation: e.g. 'a MorphicNode[3]'
  toString: ->
    "a MorphicNode" + "[" + @children.length + "]"

  # currently unused in ZK
  childrenTopToBottom: ->
    arrayShallowCopyAndReverse(@children)  
  
  # MorphicNode accessing:
  addChild: (aMorphicNode) ->
    @children.push aMorphicNode
    aMorphicNode.parent = @
    @connectValuesToAddedChild aMorphicNode
  
  addChildFirst: (aMorphicNode) ->
    @children.splice 0, null, aMorphicNode
    aMorphicNode.parent = @
  
  removeChild: (aMorphicNode) ->
    idx = @children.indexOf(aMorphicNode)
    @children.splice idx, 1  if idx isnt -1
    aMorphicNode.parent = null
    @disconnectValuesFromRemovedChild aMorphicNode
  
  
  # MorphicNode functions:
  root: ->
    return @parent.root() if @parent?
    @
  
  # currently unused
  depth: ->
    return 0  unless @parent
    @parent.depth() + 1
  
  # Returns all the internal AND terminal nodes in the subtree starting
  # at this node - including this node.
  # Remember that the @children property already sorts morphs
  # from bottom to top

  allChildrenBottomToTop: ->
    result = [@] # includes myself
    @children.forEach (child) ->
      result = result.concat(child.allChildrenBottomToTop())
    result

  # the easiest way here would be to just return
  #   arrayShallowCopyAndReverse(@allChildrenBottomToTop())
  # but that's slower.
  # So we do the proper visit here instead.
  allChildrenTopToBottom: ->
    # base case - I am a leaf child, so I just
    # return an array with myself
    # note that I return an array rather than the
    # element cause this method is always expected
    # to return an array.
    if @children.length == 0
      return [@]

    # if I have some children instead, then let's create
    # an empty array where we'll concatenate the
    # others.
    arrayToReturn = []

    # if I have children, then start from the top
    # one (i.e. the last in the array) towards the bottom
    # one and concatenate their respective
    # top-to-bottom lists
    for morphNumber in [@children.length-1..0] by -1
      morph = @children[morphNumber]
      arrayToReturn = arrayToReturn.concat morph.allChildrenTopToBottom

    # ok, last we add ourselves to the bottom
    # of the list since this node is at the bottom of all of
    # its children...
    arrayToReturn.push @


  # A shorthand to run a function on all the internal/terminal nodes in the subtree
  # starting at this node - including this node.
  # Note that the function first runs on this node (which is the bottom-est morph)
  # and the proceeds by visiting the "bottom" child (first one in array)
  # and then all its children and then the second - bottomest child etc.
  # Also note that there is a more elegant implementation where
  # we just use @allChildrenBottomToTop() but that would mean to create
  # all the intermediary arrays with also all the unneeded node elements,
  # there is not need.
  forAllChildrenBottomToTop: (aFunction) ->
    aFunction.call null, @
    if @children.length
      @children.forEach (child) ->
        child.forAllChildrenBottomToTop aFunction
  
  # not used in ZK so far
  allLeafsBottomToTop: ->
    if @children.length == 0
      return [@]
    @children.forEach (child) ->
      result = result.concat(child.allLeafsBottomToTop())
    return result

  # Return all "parent" nodes from the root up to this node (including both)
  allParentsBottomToTop: ->
    if @parent?
      someParents = @parent.allParentsBottomToTop()
      someParents.push @
      return someParents
    else
      return [@]
  
  # Return all "parent" nodes from this node up to the root (including both)
  # Implementation commented-out below works but it's probably
  # slower than the one given, because concat is slower than pushing just
  # an array element, since concat does a shallow copy of both parts of
  # the array...
  #   allParentsTopToBottom: ->
  #    # includes myself
  #    result = [@]
  #    if @parent?
  #      result = result.concat(@parent.allParentsTopToBottom())
  #    result

  allParentsTopToBottom: ->
    return @allParentsBottomToTop().reverse()

  # this should be quicker than allParentsTopToBottomSuchThat
  # cause there are no concats making shallow copies.
  allParentsBottomToTopSuchThat: (predicate) ->
    result = []
    if @parent?
      result = @parent.allParentsBottomToTopSuchThat(predicate)
    if predicate.call(null, @)
      result.push @
    result

  allParentsTopToBottomSuchThat: (predicate) ->
    collected = []
    if predicate.call(null, @)
      collected = [@] # include myself
    if @parent?
      collected = collected.concat(@parent.allParentsTopToBottomSuchThat(predicate))
    return collected

  # quicker version that doesn't need us
  # to create any intermediate arrays
  # but rather just loops up the chain
  # and lets us return as soon as
  # we find a match
  containedInParentsOf: (morph) ->
    if !morph?
      # this happens when in a test, you select
      # a menu entry that doesn't exist.
      # so it's a good thing that we block the test
      # and let the user navigate through the world
      # to find the state of affairs that caused
      # the problem.
      console.log "failed to find morph in test: " + window.world.systemTestsRecorderAndPlayer.name
      console.log "trying to find item with text label: " +  window.world.systemTestsRecorderAndPlayer.testCommandsSequence[window.world.systemTestsRecorderAndPlayer.indexOfTestCommandBeingPlayedFromSequence].textLabelOfClickedItem
      console.log "...you can likely fix the test by correcting the label above in the test"
      debugger
    # test the morph itself
    if morph is @
      return true
    examinedMorph = morph
    while examinedMorph.parent?
      examinedMorph = examinedMorph.parent
      if examinedMorph is @
        return true
    return false

  # The direct children of the parent of this node. (current node not included)
  # never used in ZK
  # There is an alternative solution here below, in comment,
  # but I believe to be slower because it requires applying a function to
  # all the children. My version below just required an array copy, then
  # finding an element and splicing it out. I didn't test it so I don't
  # even know whether it works, but gut feeling...
  #  siblings: ->
  #    return []  unless @parent
  #    @parent.children.filter (child) =>
  #      child isnt @
  siblings: ->
    return []  unless @parent
    siblings = arrayShallowCopy @parent.children
    # now remove myself
    index = siblings.indexOf(@)
    siblings.splice(index, 1)
    return siblings

  # find how many siblings before me
  # satisfy a property
  # This is used when figuring out
  # how many buttons before a particular button
  # are labeled in the same way,
  # in the test system.
  # (so that we can say: automatically
  # click on the nth button labelled "X")
  howManySiblingsBeforeMeSuchThat: (predicate) ->
    theCount = 0
    for eachSibling in @parent.children
      if eachSibling == @
        return theCount
      if predicate.call(null, eachSibling)
        theCount++
    return theCount

  # find the nth child satisfying
  # a property.
  # This is used when finding
  # the nth buttons of a menu
  # having a particular label.
  # (so that we can say: automatically
  # click on the nth button labelled "X")
  nthChildSuchThat: (n, predicate) ->
    theCount = 0
    for eachChild in @children
      if predicate.call(null, eachChild)
        theCount++
        if theCount is n
          return eachChild
    return null
  
  # returns the first parent (going up from this node) that is of a particular class
  # (includes this particular node)
  # This is a subcase of "parentThatIsAnyOf".
  parentThatIsA: (constructor) ->
    # including myself
    return @ if @ instanceof constructor
    return null  unless @parent
    @parent.parentThatIsA constructor
  
  # returns the first parent (going up from this node) that belongs to a set
  # of classes. (includes this particular node).
  parentThatIsAnyOf: (constructors) ->
    # including myself
    constructors.forEach (each) =>
      if @constructor is each
        return @
    #
    return null  unless @parent
    @parent.parentThatIsAnyOf constructors

  # There is a simpler implementation that is also
  # slower where you first collect all the children
  # from top to bottom and then do the test on each
  # But this more efficient - we don't need to
  # create that entire list to start with, we just
  # navigate through the children arrays.
  topMorphSuchThat: (predicate) ->
    # base case - I am a leaf child, so I just test
    # the predicate on myself and return myself
    # if I satisfy, else I return null
    if @children.length == 0
      if predicate.call(null, @)
        return @
      else
        return null
    # if I have children, then start to test from
    # the top one (the last one in the array)
    # and proceed to test "towards the back" i.e.
    # testing elements of the array towards 0
    # If you find any morph satifies, the search is
    # over.
    for morphNumber in [@children.length-1..0] by -1
      morph = @children[morphNumber]
      foundMorph = morph.topMorphSuchThat(predicate)
      if foundMorph?
        return foundMorph
    # now that all children are tested, test myself
    if predicate.call(null, @)
      return @
    else
      return null
    # ok none of my children nor me test positive,
    # so return null.
    return null

  topmostChildSuchThat: (predicate) ->
    # start to test from
    # the top one (the last one in the array)
    # and proceed to test "towards the back" i.e.
    # testing elements of the array towards 0
    # If you find any child that satifies, the search is
    # over.
    for morphNumber in [@children.length-1..0] by -1
      morph = @children[morphNumber]
      if predicate.call(null, morph)
        return morph
    # ok none of my children test positive,
    # so return null.
    return null

  collectAllChildrenBottomToTopSuchThat: (predicate) ->
    collected = []
    if predicate.call(null, @)
      collected = [@] # include myself
    @children.forEach (child) ->
      collected = collected.concat(child.collectAllChildrenBottomToTopSuchThat(predicate))
    return collected
  '''

# Morph //////////////////////////////////////////////////////////////

# A Morph (from the Greek "shape" or "form") is an interactive
# graphical object. General information on the Morphic system
# can be found at http://minnow.cc.gatech.edu/squeak/30. 

# Morphs exist in a tree, rooted at a World or at the Hand.
# The morphs owns submorphs. Morphs are drawn recursively;
# if a Morph has no owner it never gets drawn
# (but note that there are other ways to hide a Morph).

# this comment below is needed to figure our dependencies between classes
# REQUIRES globalFunctions

class Morph extends MorphicNode

  # we want to keep track of how many instances we have
  # of each Morph for a few reasons:
  # 1) it gives us an identifier for each Morph
  # 2) profiling
  # 3) generate a uniqueIDString that we can use
  #    for example for hashtables
  # each subclass of Morph has its own static
  # instancesCounter which starts from zero. First object
  # has instanceNumericID of 1.
  # instanceNumericID is initialised in the constructor.
  @instancesCounter: 0
  # see roundNumericIDsToNextThousand method for an
  # explanation of why we need to keep this extra
  # count
  @lastBuiltInstanceNumericID: 0
  instanceNumericID: 0
  
  # Just some tests here ////////////////////
  propertyUpTheChain: [1,2,3]
  morphMethod: ->
    3.14
  @morphStaticMethod: ->
    3.14
  # End of tests here ////////////////////

  isMorph: true
  bounds: null
  color: null
  texture: null # optional url of a fill-image
  cachedTexture: null # internal cache of actual bg image
  lastTime: null
  alpha: 1

  # for a Morph, being visible and minimised
  # are two separate things.
  # isVisible means that the morph is meant to show
  #  as empty or without any surface. For example
  #  a scrollbar "collapses" itself when there is no
  #  content to scroll and puts its isVisible = false
  # isMinimised means that the morph, whatever its
  #  content or appearance or design, is not drawn
  #  on the desktop. So a minimised or unminimised scrollbar
  #  can be independently either visible or not.
  # If we merge the two flags into one, then the
  # following happens: "hiding" a morph causes the
  # scrollbars in it to hide. Unhiding it causes the
  # scrollbars to show, even if they should be invisible.
  # Hence the need of two separate flags.
  # Also, it's semantically two
  # separate reasons of why a morph is not being
  # painted on screen, so it makes sense to have
  # two separate flags.
  isMinimised: false
  isVisible: true

  isDraggable: false
  isTemplate: false
  acceptsDrops: false
  noticesTransparentClick: false
  fps: 0
  customContextMenu: null
  trackChanges: true
  shadowBlur: 10
  # note that image contains only the CURRENT morph, not the composition of this
  # morph with all of the submorphs. I.e. for an inspector, this will only
  # contain the background of the window pane. Not any of its contents.
  # for the worldMorph, this only contains the background
  image: null
  onNextStep: null # optional function to be run once. Not currently used in Zombie Kernel

  # contains all the reactive vals
  allValsInMorphByName: null
  morphValsDependingOnChildrenVals: null
  morphValsDirectlyDependingOnParentVals: null

  ##########################################################
  # These two methods are for mixins
  ##########################################################
  # adds class properties
  @augmentWith: (obj) ->
    for key, value of obj when key not in MixedClassKeywords
      @[key] = value
    obj.onceAddedClassProperties?.apply(@)
    this

  # adds instance properties
  @addInstanceProperties: (obj) ->
    for key, value of obj when key not in MixedClassKeywords
      # Assign properties to the prototype
      @::[key] = value
    obj.included?.apply(@)
    this
  ################# end of mixins methods ##################

  ##########################################################
  # Reactive Values start
  ##########################################################


  connectValuesToAddedChild: (theChild) ->
    #if theChild.constructor.name == "RectangleMorph"
    #  debugger

    # we have a data structure that contains,
    # for each child valName, all vals of this
    # morph that depend on it. Go through
    # all child val names, find the
    # actual val in the child, and connect all
    # to the vals in this morph that depend on it.
    for nameOfChildrenVar, morphValsDependingOnChildrenVals of \
        @morphValsDependingOnChildrenVals
      childVal = theChild.allValsInMorphByName[ nameOfChildrenVar ]
      if childVal?
        for valNameNotUsed, valDependingOnChildrenVal of morphValsDependingOnChildrenVals
          valDependingOnChildrenVal.args.connectToChildVal valDependingOnChildrenVal, childVal

    # we have a data structure that contains,
    # for each parent (me) valName, all vals of the child
    # morph that depend on it. Go through
    # all parent (me) val names, find the
    # actual val in the parent (me), and connect it
    # to the vals in the child morph that depend on it.
    for nameOfParentVar, morphValsDirectlyDependingOnParentVals of \
        theChild.morphValsDirectlyDependingOnParentVals
      parentVal = @allValsInMorphByName[ nameOfParentVar ]
      if parentVal?
        for valNameNotUsed, valDependingOnParentVal of morphValsDirectlyDependingOnParentVals
          valDependingOnParentVal.args.connectToParentVal valDependingOnParentVal, parentVal

  disconnectValuesFromRemovedChild: (theChild) ->
    # we have a data structure that contains,
    # for each child valName, all vals of this
    # morph that depend on it. Go through
    # all child val names, find the
    # actual val in the child, and DISconnect it
    # FROM the vals in this morph that depended on it.
    for nameOfChildrenVar, morphValsDependingOnChildrenVals of \
        @morphValsDependingOnChildrenVals
      for valNameNotUsed, valDependingOnChildrenVal of morphValsDependingOnChildrenVals
        childArg = valDependingOnChildrenVal.args.argById[theChild.id]
        if childArg?
          childArg.disconnectChildArg()

    # we have a data structure that contains,
    # for each parent (me) valName, all vals of the child
    # morph that depend on it. Go through
    # all parent (me) val names, find the
    # actual val in the parent (me), and connect it
    # to the vals in the child morph that depend on it.
    for nameOfParentVar, morphValsDirectlyDependingOnParentVals of \
        theChild.morphValsDirectlyDependingOnParentVals
      for valNameNotUsed, valDependingOnParentVal of morphValsDirectlyDependingOnParentVals
        parentArg = valDependingOnParentVal.args.parentArgByName[ nameOfParentVar ]
        if parentArg?
          parentArg.disconnectParentArg()


  ############## end of reactive values ##########################

  uniqueIDString: ->
    @morphClassString() + "#" + @instanceNumericID

  morphClassString: ->
    (@constructor.name or @constructor.toString().split(" ")[1].split("(")[0])

  @morphFromUniqueIDString: (theUniqueID) ->
    result = world.topMorphSuchThat (m) =>
      m.uniqueIDString() is theUniqueID
    if not result?
      alert "theUniqueID " + theUniqueID + " not found!"
    return result

  assignUniqueID: ->
    @constructor.instancesCounter++
    @constructor.lastBuiltInstanceNumericID++
    @instanceNumericID = @constructor.lastBuiltInstanceNumericID

  # some test commands specify morphs via
  # their uniqueIDString. This means that
  # if there is one more TextMorph anywhere during
  # the playback, for example because
  # one new menu item is added, then
  # all the subsequent IDs for the TextMorph will be off.
  # In order to sort that out, we occasionally re-align
  # the counts to the next 1000, so the next Morphs
  # being created will all be aligned and
  # minor discrepancies are ironed-out
  @roundNumericIDsToNextThousand: ->
    console.log "@roundNumericIDsToNextThousand"
    # this if is because zero and multiples of 1000
    # don't go up to 1000
    if @lastBuiltInstanceNumericID %1000 == 0
      @lastBuiltInstanceNumericID++
    @lastBuiltInstanceNumericID = 1000*Math.ceil(@lastBuiltInstanceNumericID/1000)

  constructor: ->
    super()
    @assignUniqueID()

    # [TODO] why is there this strange non-zero default bound?
    @bounds = new Rectangle(0, 0, 50, 40)
    @color = @color or new Color(80, 80, 80)
    @lastTime = Date.now()
    # Note that we don't call @updateRendering()
    # that's because the actual extending morph will probably
    # set more details of how it should look (e.g. size),
    # so we wait and we let the actual extending
    # morph to draw itself.

    @allValsInMorphByName = {}
    @morphValsDependingOnChildrenVals = {}
    @morphValsDirectlyDependingOnParentVals = {}


  
  #
  #    damage list housekeeping
  #
  #	the trackChanges property of the Morph prototype is a Boolean switch
  #	that determines whether the World's damage list ('broken' rectangles)
  #	tracks changes. By default the switch is always on. If set to false
  #	changes are not stored. This can be very useful for housekeeping of
  #	the damage list in situations where a large number of (sub-) morphs
  #	are changed more or less at once. Instead of keeping track of every
  #	single submorph's changes tremendous performance improvements can be
  #	achieved by setting the trackChanges flag to false before propagating
  #	the layout changes, setting it to true again and then storing the full
  #	bounds of the surrounding morph. An an example refer to the
  #
  #		layoutSubmorphs()
  #		
  #	method of InspectorMorph, or the
  #	
  #		startLayout()
  #		endLayout()
  #
  #	methods of SyntaxElementMorph in the Snap application.
  #
  
  
  # Morph string representation: e.g. 'a Morph#2 [20@45 | 130@250]'
  toString: ->
    firstPart = "a "

    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.hidingOfMorphsNumberIDInLabels
      firstPart = firstPart + @morphClassString()
    else
      firstPart = firstPart + @uniqueIDString()

    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.hidingOfMorphsGeometryInfoInLabels
      return firstPart
    else
      return firstPart + " " + @bounds

  # Morph string representation: e.g. 'a Morph#2'
  toStringWithoutGeometry: ->
    "a " +
      @uniqueIDString()
  
  
  # Morph deleting:
  destroy: ->
    # todo there is something to be figured out here
    # cause in theory ALL the morphs in here are not
    # visible, not just the parent... but it kind of
    # seems overkill...
    @visible = false
    if @parent?
      @fullChanged()
      @parent.removeChild @
    return null
  
  destroyAll: ->
    # we can't use forEach because we are iterating over
    # an array that changes its values (and length) while
    # we are iterating on it.
    until @children.length == 0
      @children[0].destroy()
    return null

  # Morph stepping:
  runChildrensStepFunction: ->
    # step is the function that this Morph wants to run at each step.
    # If the Morph wants to do nothing and let no-one of the children do nothing,
    # then step is set to null.
    # If the morph wants to do nothing but the children might want to do something,
    # then step is set to the function that does nothing (i.e. a function noOperation that
    # only returns null) 
    return null  unless @step

    # for objects where @fps is defined, check which ones are due to be stepped
    # and which ones want to wait. 
    elapsed = WorldMorph.currentTime - @lastTime
    if @fps > 0
      timeRemainingToWaitedFrame = (1000 / @fps) - elapsed
    else
      timeRemainingToWaitedFrame = 0
    
    # Question: why 1 here below?
    if timeRemainingToWaitedFrame < 1
      @lastTime = WorldMorph.currentTime
      if @onNextStep
        nxt = @onNextStep
        @onNextStep = null
        nxt.call(@)
      @step()
      @children.forEach (child) ->
        child.runChildrensStepFunction()

  # not used within Zombie Kernel yet.
  nextSteps: (arrayOfFunctions) ->
    lst = arrayOfFunctions or []
    nxt = lst.shift()
    if nxt
      @onNextStep = =>
        nxt.call @
        @nextSteps lst  
  
  # leaving this function as step means that the morph wants to do nothing
  # but the children *are* traversed and their step function is invoked.
  # If a Morph wants to do nothing and wants to prevent the children to be
  # traversed, then this function should be set to null.
  step: noOperation
  
  
  # Morph accessing - geometry getting:
  left: ->
    @bounds.left()
  
  right: ->
    @bounds.right()
  
  top: ->
    @bounds.top()
  
  bottom: ->
    @bounds.bottom()
  
  center: ->
    @bounds.center()
  
  bottomCenter: ->
    @bounds.bottomCenter()
  
  bottomLeft: ->
    @bounds.bottomLeft()
  
  bottomRight: ->
    @bounds.bottomRight()
  
  boundingBox: ->
    @bounds
  
  corners: ->
    @bounds.corners()
  
  leftCenter: ->
    @bounds.leftCenter()
  
  rightCenter: ->
    @bounds.rightCenter()
  
  topCenter: ->
    @bounds.topCenter()
  
  topLeft: ->
    @bounds.topLeft()
  
  topRight: ->
    @bounds.topRight()
  
  position: ->
    @bounds.origin
  
  extent: ->
    @bounds.extent()
  
  width: ->
    @bounds.width()
  
  height: ->
    @bounds.height()


  # used for example:
  # - to determine which morphs you can attach a morph to
  # - for a SliderMorph's "set target" so you can change properties of another Morph
  # - by the HandleMorph when you attach it to some other morph
  # Note that this method has a slightly different
  # version in FrameMorph (because it clips, so we need
  # to check that we don't consider overlaps with
  # morphs contained in a frame that are clipped and
  # hence *actually* not overlapping).
  plausibleTargetAndDestinationMorphs: (theMorph) ->
    # find if I intersect theMorph,
    # then check my children recursively
    # exclude me if I'm a child of theMorph
    # (cause it's usually odd to attach a Morph
    # to one of its submorphs or for it to
    # control the properties of one of its submorphs)
    result = []
    if !@isMinimised and
        @isVisible and
        !theMorph.containedInParentsOf(@) and
        @bounds.intersects(theMorph.bounds)
      result = [@]

    @children.forEach (child) ->
      result = result.concat(child.plausibleTargetAndDestinationMorphs(theMorph))

    return result

  
  boundsIncludingChildren: ->
    result = @bounds
    @children.forEach (child) ->
      if !child.isMinimised and child.isVisible
        result = result.merge(child.boundsIncludingChildren())
    result
  
  boundsIncludingChildrenNoShadow: ->
    # answer my full bounds but ignore any shadow
    result = @bounds
    @children.forEach (child) ->
      if (child not instanceof ShadowMorph) and (!child.isMinimised) and (child.isVisible)
        result = result.merge(child.boundsIncludingChildrenNoShadow())
    result
  
  visibleBounds: ->
    # answer which part of me is not clipped by a Frame
    visible = @bounds
    frames = @allParentsTopToBottomSuchThat (p) ->
      p instanceof FrameMorph
    frames.forEach (f) ->
      visible = visible.intersect(f.bounds)
    #
    visible
  
  
  # Morph accessing - simple changes:
  moveBy: (delta) ->
    # note that changed() is called two times
    # because there are two areas of the screens
    # that are dirty: the starting
    # position and the end position.
    # Both need to be repainted.
    @changed()
    @bounds = @bounds.translateBy(delta)
    @children.forEach (child) ->
      child.moveBy delta
    #
    @changed()
  
  silentMoveBy: (delta) ->
    @bounds = @bounds.translateBy(delta)
    @children.forEach (child) ->
      child.silentMoveBy delta
  
  
  setPosition: (aPoint) ->
    delta = aPoint.subtract(@topLeft())
    @moveBy delta  if (delta.x isnt 0) or (delta.y isnt 0)
  
  silentSetPosition: (aPoint) ->
    delta = aPoint.subtract(@topLeft())
    @silentMoveBy delta  if (delta.x isnt 0) or (delta.y isnt 0)
  
  setLeft: (x) ->
    @setPosition new Point(x, @top())
  
  setRight: (x) ->
    @setPosition new Point(x - @width(), @top())
  
  setTop: (y) ->
    @setPosition new Point(@left(), y)
  
  setBottom: (y) ->
    @setPosition new Point(@left(), y - @height())
  
  setCenter: (aPoint) ->
    @setPosition aPoint.subtract(@extent().floorDivideBy(2))
  
  setFullCenter: (aPoint) ->
    @setPosition aPoint.subtract(@boundsIncludingChildren().extent().floorDivideBy(2))
  
  # make sure I am completely within another Morph's bounds
  keepWithin: (aMorph) ->
    leftOff = @boundsIncludingChildren().left() - aMorph.left()
    @moveBy new Point(-leftOff, 0)  if leftOff < 0
    rightOff = @boundsIncludingChildren().right() - aMorph.right()
    @moveBy new Point(-rightOff, 0)  if rightOff > 0
    topOff = @boundsIncludingChildren().top() - aMorph.top()
    @moveBy new Point(0, -topOff)  if topOff < 0
    bottomOff = @boundsIncludingChildren().bottom() - aMorph.bottom()
    @moveBy new Point(0, -bottomOff)  if bottomOff > 0
  
  # the default of layoutSubmorphs
  # is to do nothing, but things like
  # the inspector might well want to
  # tweak many of theor children...
  layoutSubmorphs: ->
    null
  
  # Morph accessing - dimensional changes requiring a complete redraw
  setExtent: (aPoint) ->
    # check whether we are actually changing the extent.
    unless aPoint.eq(@extent())
      @changed()
      @silentSetExtent aPoint
      @changed()
      @updateRendering()
      @layoutSubmorphs()
  
  silentSetExtent: (aPoint) ->
    ext = aPoint.round()
    newWidth = Math.max(ext.x, 0)
    newHeight = Math.max(ext.y, 0)
    @bounds.corner = new Point(@bounds.origin.x + newWidth, @bounds.origin.y + newHeight)
  
  setWidth: (width) ->
    @setExtent new Point(width or 0, @height())
  
  silentSetWidth: (width) ->
    # do not updateRendering() just yet
    w = Math.max(Math.round(width or 0), 0)
    @bounds.corner = new Point(@bounds.origin.x + w, @bounds.corner.y)
  
  setHeight: (height) ->
    @setExtent new Point(@width(), height or 0)
  
  silentSetHeight: (height) ->
    # do not updateRendering() just yet
    h = Math.max(Math.round(height or 0), 0)
    @bounds.corner = new Point(@bounds.corner.x, @bounds.origin.y + h)
  
  setColor: (aColorOrAMorphGivingAColor) ->
    if aColorOrAMorphGivingAColor.getColor?
      aColor = aColorOrAMorphGivingAColor.getColor()
    else
      aColor = aColorOrAMorphGivingAColor
    if aColor
      unless @color.eq(aColor)
        @color = aColor
        @changed()
        @updateRendering()
  
  
  # Morph displaying ###########################################################

  # There are three fundamental methods for rendering and displaying anything.
  # * updateRendering: this one creates/updates the local canvas of this morph only
  #   i.e. not the children. For example: a ColorPickerMorph is a Morph which
  #   contains three children Morphs (a color palette, a greyscale palette and
  #   a feedback). The updateRendering method of ColorPickerMorph only creates
  #   a canvas for the container Morph. So that's just a canvas with a
  #   solid color. As the
  #   ColorPickerMorph constructor runs, the three childredn Morphs will
  #   run their own updateRendering method, so each child will have its own
  #   canvas with their own contents.
  #   Note that updateRendering should be called sparingly. A morph should repaint
  #   its buffer pretty much only *after* it's been added to itf first parent and
  #   whenever it changes dimensions. Things like changing parent and updating
  #   the position shouldn't normally trigger an update of the buffer.
  #   Also note that before the buffer is painted for the first time, they
  #   might not know their extent. Typically text-related Morphs know their
  #   extensions after they painted the text for the first time...
  # * blit: takes the local canvas and blits it to a specific area in a passed
  #   canvas. The local canvas doesn't contain any rendering of the children of
  #   this morph.
  # * recursivelyBlit: recursively draws all the local canvas of this morph and all
  #   its children into a specific area of a passed canvas.

  updateRendering: ->
    # initialize my surface property
    @image = newCanvas(@extent().scaleBy pixelRatio)
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    context.fillStyle = @color.toString()
    context.fillRect 0, 0, @width(), @height()
    if @cachedTexture
      @drawCachedTexture()
    else @drawTexture @texture  if @texture
    @changed()
  
  drawTexture: (url) ->
    @cachedTexture = new Image()
    @cachedTexture.onload = =>
      @drawCachedTexture()
    #
    @cachedTexture.src = @texture = url # make absolute
  
  # tiles the texture
  drawCachedTexture: ->
    bg = @cachedTexture
    cols = Math.floor(@image.width / bg.width)
    lines = Math.floor(@image.height / bg.height)
    context = @image.getContext("2d")
    for y in [0..lines]
      for x in [0..cols]
        context.drawImage bg, Math.round(x * bg.width), Math.round(y * bg.height)
    @changed()
  
  
  #
  #Morph.prototype.drawCachedTexture = function () {
  #    var context = this.image.getContext('2d'),
  #        pattern = context.createPattern(this.cachedTexture, 'repeat');
  #	context.fillStyle = pattern;
  #    context.fillRect(0, 0, this.image.width, this.image.height);
  #    this.changed();
  #};
  #
  
  # This method only paints this very morph's "image",
  # it doesn't descend the children
  # recursively. The recursion mechanism is done by recursivelyBlit, which
  # eventually invokes blit.
  # Note that this morph might paint something on the screen even if
  # it's not a "leaf".
  blit: (aCanvas, clippingRectangle) ->
    return null  if @isMinimised or !@isVisible or !@image?
    area = clippingRectangle.intersect(@bounds).round()
    # test whether anything that we are going to be drawing
    # is visible (i.e. within the clippingRectangle)
    if area.isNotEmpty()
      delta = @position().neg()
      src = area.copy().translateBy(delta).round()
      context = aCanvas.getContext("2d")
      context.globalAlpha = @alpha
      sl = src.left() * pixelRatio
      st = src.top() * pixelRatio
      al = area.left() * pixelRatio
      at = area.top() * pixelRatio
      w = Math.min(src.width() * pixelRatio, @image.width - sl)
      h = Math.min(src.height() * pixelRatio, @image.height - st)
      return null  if w < 1 or h < 1

      context.drawImage @image,
        Math.round(sl),
        Math.round(st),
        Math.round(w),
        Math.round(h),
        Math.round(al),
        Math.round(at),
        Math.round(w),
        Math.round(h)

      if world.showRedraws
        randomR = Math.round(Math.random()*255)
        randomG = Math.round(Math.random()*255)
        randomB = Math.round(Math.random()*255)
        context.globalAlpha = 0.5
        context.fillStyle = "rgb("+randomR+","+randomG+","+randomB+")";
        context.fillRect(Math.round(al),Math.round(at),Math.round(w),Math.round(h));
  
  
  # "for debugging purposes:"
  #
  #		try {
  #			context.drawImage(
  #				this.image,
  #				src.left(),
  #				src.top(),
  #				w,
  #				h,
  #				area.left(),
  #				area.top(),
  #				w,
  #				h
  #			);
  #		} catch (err) {
  #			alert('internal error\n\n' + err
  #				+ '\n ---'
  #				+ '\n canvas: ' + aCanvas
  #				+ '\n canvas.width: ' + aCanvas.width
  #				+ '\n canvas.height: ' + aCanvas.height
  #				+ '\n ---'
  #				+ '\n image: ' + this.image
  #				+ '\n image.width: ' + this.image.width
  #				+ '\n image.height: ' + this.image.height
  #				+ '\n ---'
  #				+ '\n w: ' + w
  #				+ '\n h: ' + h
  #				+ '\n sl: ' + sl
  #				+ '\n st: ' + st
  #				+ '\n area.left: ' + area.left()
  #				+ '\n area.top ' + area.top()
  #				);
  #		}
  #	
  recursivelyBlit: (aCanvas, clippingRectangle = @boundsIncludingChildren()) ->
    return null  if @isMinimised or !@isVisible

    # in general, the children of a Morph could be outside the
    # bounds of the parent (they could also be much larger
    # then the parent). This means that we have to traverse
    # all the children to find out whether any of those overlap
    # the clipping rectangle. Note that we can be smarter with
    # FrameMorphs, as their children are actually all contained
    # within the parent's boundary.

    # Note that if we could dynamically and cheaply keep an updated
    # boundsIncludingChildren property, then we could be smarter
    # in discarding whole sections of the scene graph.
    # (see https://github.com/davidedc/Zombie-Kernel/issues/150 )

    @blit aCanvas, clippingRectangle
    @children.forEach (child) ->
      child.recursivelyBlit aCanvas, clippingRectangle
  

  hide: ->
    @isVisible = false
    @changed()
    @children.forEach (child) ->
      child.hide()

  show: ->
    @isVisible = true
    @changed()
    @children.forEach (child) ->
      child.show()
  
  minimise: ->
    @isMinimised = true
    @changed()
    @children.forEach (child) ->
      child.minimise()
  
  unminimise: ->
    @isMinimised = false
    @changed()
    @children.forEach (child) ->
      child.unminimise()
  
  
  toggleVisibility: ->
    @isMinimised = (not @isMinimised)
    @changed()
    @children.forEach (child) ->
      child.toggleVisibility()
  
  
  # Morph full image:
  
  # Fixes https://github.com/jmoenig/morphic.js/issues/7
  # and https://github.com/davidedc/Zombie-Kernel/issues/160
  fullImage: ->
    boundsIncludingChildren = @boundsIncludingChildren()
    img = newCanvas(boundsIncludingChildren.extent().scaleBy pixelRatio)
    ctx = img.getContext("2d")
    # ctx.scale pixelRatio, pixelRatio
    # we are going to draw this morph and its children into "img".
    # note that the children are not necessarily geometrically
    # contained in the morph (in which case it would be ok to
    # translate the context so that the origin of *this* morph is
    # at the top-left of the "img" canvas).
    # Hence we have to translate the context
    # so that the origin of the entire boundsIncludingChildren is at the
    # very top-left of the "img" canvas.
    ctx.translate -boundsIncludingChildren.origin.x * pixelRatio , -boundsIncludingChildren.origin.y * pixelRatio
    @recursivelyBlit img, boundsIncludingChildren
    img

  fullImageData: ->
    # returns a string like "data:image/png;base64,iVBORw0KGgoAA..."
    # note that "image/png" below could be omitted as it's
    # the default, but leaving it here for clarity.
    @fullImage().toDataURL("image/png")

  fullImageHashCode: ->
    return hashCode(@fullImageData())
  
  # Morph shadow:
  shadowImage: (off_, color) ->
    # fallback for Windows Chrome-Shadow bug
    offset = off_ or new Point(7, 7)
    clr = color or new Color(0, 0, 0)
    fb = @boundsIncludingChildren().extent()
    img = @fullImage()
    outline = newCanvas(fb.scaleBy pixelRatio)
    ctx = outline.getContext("2d")
    #ctx.scale pixelRatio, pixelRatio
    ctx.drawImage img, 0, 0
    ctx.globalCompositeOperation = "destination-out"
    ctx.drawImage img, Math.round(-offset.x) * pixelRatio, Math.round(-offset.y) * pixelRatio
    sha = newCanvas(fb.scaleBy pixelRatio)
    ctx = sha.getContext("2d")
    #ctx.scale pixelRatio, pixelRatio
    ctx.drawImage outline, 0, 0
    ctx.globalCompositeOperation = "source-atop"
    ctx.fillStyle = clr.toString()
    ctx.fillRect 0, 0, fb.x * pixelRatio, fb.y * pixelRatio
    sha
  
  # the one used right now
  shadowImageBlurred: (off_, color) ->
    offset = off_ or new Point(7, 7)
    blur = @shadowBlur
    clr = color or new Color(0, 0, 0)
    fb = @boundsIncludingChildren().extent().add(blur * 2)
    img = @fullImage()
    sha = newCanvas(fb.scaleBy pixelRatio)
    ctx = sha.getContext("2d")
    #ctx.scale pixelRatio, pixelRatio
    ctx.shadowOffsetX = offset.x * pixelRatio
    ctx.shadowOffsetY = offset.y * pixelRatio
    ctx.shadowBlur = blur * pixelRatio
    ctx.shadowColor = clr.toString()
    ctx.drawImage img, Math.round((blur - offset.x)*pixelRatio), Math.round((blur - offset.y)*pixelRatio)
    ctx.shadowOffsetX = 0
    ctx.shadowOffsetY = 0
    ctx.shadowBlur = 0
    ctx.globalCompositeOperation = "destination-out"
    ctx.drawImage img, Math.round((blur - offset.x)*pixelRatio), Math.round((blur - offset.y)*pixelRatio)
    sha
  
  
  # shadow is added to a morph by
  # the HandMorph while dragging
  addShadow: (offset, alpha, color) ->
    shadow = new ShadowMorph(@, offset, alpha, color)
    @addBack shadow
    @fullChanged()
    shadow
  
  getShadow: ->
    return @topmostChildSuchThat (child) ->
      child instanceof ShadowMorph
  
  removeShadow: ->
    shadow = @getShadow()
    if shadow?
      @fullChanged()
      @removeChild shadow
  
  
  # Morph pen trails:
  penTrails: ->
    # answer my pen trails canvas. default is to answer my image
    # The implication is that by default every Morph in the system
    # (including the World) is able to act as turtle canvas and can
    # display pen trails.
    # BUT also this means that pen trails will be lost whenever
    # the trail's morph (the pen's parent) performs a "drawNew()"
    # operation. If you want to create your own pen trails canvas,
    # you may wish to modify its **penTrails()** property, so that
    # it keeps a separate offscreen canvas for pen trails
    # (and doesn't lose these on redraw).
    @image
  
  
  # Morph updating ///////////////////////////////////////////////////////////////
  changed: ->
    if @trackChanges
      w = @root()
      # unless we are the main desktop, then if the morph has no parent
      # don't add the broken rect since the morph is not visible
      if w instanceof WorldMorph and (@ instanceof WorldMorph or @parent?)
        w.broken.push @visibleBounds().spread()
    @parent.childChanged @  if @parent
  
  fullChanged: ->
    if @trackChanges
      w = @root()
      # unless we are the main desktop, then if the morph has no parent
      # don't add the broken rect since the morph is not visible
      if w instanceof WorldMorph and ((@ instanceof WorldMorph or @parent?))
        w.broken.push @boundsIncludingChildren().spread()
  
  childChanged: ->
    # react to a  change in one of my children,
    # default is to just pass this message on upwards
    # override this method for Morphs that need to adjust accordingly
    @parent.childChanged @  if @parent
  
  
  # Morph accessing - structure //////////////////////////////////////////////
  world: ->
    root = @root()
    return root  if root instanceof WorldMorph
    return root.world  if root instanceof HandMorph
    null
  
  # attaches submorph on top
  # ??? TODO you should handle the case of Morph
  #     being added to itself and the case of
  # ??? TODO a Morph being added to one of its
  #     children
  add: (aMorph) ->
    # the morph that is being
    # attached might be attached to
    # a clipping morph. So we
    # need to do a "changed" here
    # to make sure that anything that
    # is outside the clipping Morph gets
    # painted over.
    aMorph.changed()
    owner = aMorph.parent
    owner.removeChild aMorph  if owner?
    @addChild aMorph
    aMorph.updateRendering()
  
  # attaches submorph underneath
  addBack: (aMorph) ->
    owner = aMorph.parent
    owner.removeChild aMorph  if owner?
    aMorph.updateRendering()
    # this is a curious instance where
    # we first update the rendering and then
    # we add the morph. This is because
    # the rendering depends on the
    # full extent including children of
    # the morph we are attaching the shadow
    # to. So if we add the shadow we are going
    # to influence those measurements and
    # make our life very difficult for
    # ourselves.
    @addChildFirst aMorph
  

  # never currently used in ZK
  # TBD whether this is 100% correct,
  # see "topMorphUnderPointer" implementation in
  # HandMorph.
  # Also there must be a quicker implementation
  # cause there is no need to create the entire
  # morph list. It would be sufficient to
  # navigate the structure and just return
  # at the first morph satisfying the test.
  morphAt: (aPoint) ->
    morphs = @allChildrenTopToBottom()
    result = null
    morphs.forEach (m) ->
      if m.boundsIncludingChildren().containsPoint(aPoint) and (result is null)
        result = m
    #
    result
  
  #
  #	potential alternative - solution for morphAt.
  #	Has some issues, commented out for now...
  #
  #Morph.prototype.morphAt = function (aPoint) {
  #	return this.topMorphSuchThat(function (m) {
  #		return m.boundsIncludingChildren().containsPoint(aPoint);
  #	});
  #};
  #
  
  # Morph pixel access:
  getPixelColor: (aPoint) ->
    point = aPoint.subtract(@bounds.origin)
    context = @image.getContext("2d")
    data = context.getImageData(point.x * pixelRatio, point.y * pixelRatio, 1, 1)
    new Color(data.data[0], data.data[1], data.data[2], data.data[3])
  
  isTransparentAt: (aPoint) ->
    if @bounds.containsPoint(aPoint)
      return false  if @texture
      point = aPoint.subtract(@bounds.origin)
      context = @image.getContext("2d")
      data = context.getImageData(Math.floor(point.x)*pixelRatio, Math.floor(point.y)*pixelRatio, 1, 1)
      # check the 4th byte - the Alpha (RGBA)
      return data.data[3] is 0
    false
  
  # Morph duplicating ////////////////////////////////////////////////////

  # creates a new instance of target's type
  clone: (target) ->
    #alert "cloning a " + target.constructor.name
    if typeof target is "object"
      # note that the constructor method is not run!
      theClone = Object.create(target.constructor.prototype)
      #console.log "theClone class:" + theClone.constructor.name
      theClone.assignUniqueID()
      #theClone.constructor()
      return theClone
    target

  # returns a shallow copy of target.
  # Shallow copy keeps references to original objects, arrays or functions
  # within the new object, so the “copy” is still linked to the original
  # object. In other words, they will be pointing to the same memory
  # location. String and Numbers are duplicated instead.
  shallowCopy: (target) ->
    c = @clone(target.constructor::)
    for property of target
      # there are a couple of properties that we don't want to copy over...
      if target.hasOwnProperty(property) and property != "instanceNumericID"
        c[property] = target[property]
        #if target.constructor.name == "SliderMorph"
        #  alert "copying property: " + property
    c
  
  copy: ->
    c = @shallowCopy(@)
    c.parent = null
    c.children = []
    c.bounds = @bounds.copy()
    c
  
  copyRecordingReferences: (dict) ->
    # copies a Morph, its properties and its submorphs. Properties
    # are shallow-copied, so for example Numbers and Strings
    # are actually duplicated,
    # but arrays objects and functions are not deep-copied i.e.
    # just the references are copied.
    # Also builds a correspondence of the morph and its submorphs to their
    # respective clones.

    c = @copy()
    # "dict" maps the correspondences from this object to the
    # copy one. So dict[propertyOfThisObject] = propertyOfCopyObject
    dict[@uniqueIDString()] = c
    @children.forEach (m) ->
      # the result of this loop is that all the children of this
      # object are (recursively) copied and attached to the copy of this
      # object. dict will contain all the mappings between the
      # children of this object and the copied children.
      c.add m.copyRecordingReferences(dict)
    c
  
  fullCopy: ->
    #
    #	Produce a copy of me with my entire tree of submorphs. Morphs
    #	mentioned more than once are all directed to a single new copy.
    #	Other properties are also *shallow* copied, so you must override
    #	to deep copy Arrays and (complex) Objects
    #	
    #alert "doing a full copy"
    dict = {}
    c = @copyRecordingReferences(dict)
    # note that child.updateReferences is invoked
    # from the bottom up, i.e. from the leaf children up to the
    # parents. This is important because it means that each
    # child can properly fix the connections between the "mapped"
    # children correctly.
    #alert "### updating references"
    #alert "number of children: " + c.children.length
    c.forAllChildrenBottomToTop (child) ->
      #alert ">>> updating reference of " + child
      child.updateReferences dict
    #alert ">>> updating reference of " + c
    c.updateReferences dict
    #
    c
  
  # if the constructor of the object you are copying performs
  # some complex building and connecting of the elements,
  # and there are some callbacks around,
  # then maybe you could need to override this method.
  # The inspectorMorph needed to override this method
  # until extensive refactoring was performed.
  updateReferences: (dict) ->
    #
    #	Update intra-morph references within a composite morph that has
    #	been copied. For example, if a button refers to morph X in the
    #	orginal composite then the copy of that button in the new composite
    #	should refer to the copy of X in new composite, not the original X.
    # This is done via scanning all the properties of the object and
    # checking whether any of those has a mapping. If so, then it is
    # replaced with its mapping.
    #	
    #alert "updateReferences of " + @toString()
    for property of @
      if @[property]?
        #if property == "button"
        #  alert "!! property: " + property + " is morph: " + (@[property]).isMorph
        #  alert "dict[property]: " + dict[(@[property]).uniqueIDString()]
        if (@[property]).isMorph and dict[(@[property]).uniqueIDString()]
          #if property == "button"
          #  alert "!! updating property: " + property + " to: " + dict[(@[property]).uniqueIDString()]
          @[property] = dict[(@[property]).uniqueIDString()]
  
  
  # Morph dragging and dropping /////////////////////////////////////////
  
  rootForGrab: ->
    if @ instanceof ShadowMorph
      return @parent.rootForGrab()
    if @parent instanceof ScrollFrameMorph
      return @parent
    if @parent is null or
      @parent instanceof WorldMorph or
      @parent instanceof FrameMorph or
      @isDraggable is true
        return @  
    @parent.rootForGrab()
  
  wantsDropOf: (aMorph) ->
    # default is to answer the general flag - change for my heirs
    if (aMorph instanceof HandleMorph) or
      (aMorph instanceof MenuMorph)
        return false  
    @acceptsDrops
  
  pickUp: ->
    @setPosition world.hand.position().subtract(@extent().floorDivideBy(2))
    world.hand.grab @
  
  isPickedUp: ->
    @parentThatIsA(HandMorph)?
  
  situation: ->
    # answer a dictionary specifying where I am right now, so
    # I can slide back to it if I'm dropped somewhere else
    if @parent
      return (
        origin: @parent
        position: @position().subtract(@parent.position())
      )
    null
  
  slideBackTo: (situation, inSteps) ->
    steps = inSteps or 5
    pos = situation.origin.position().add(situation.position)
    xStep = -(@left() - pos.x) / steps
    yStep = -(@top() - pos.y) / steps
    stepCount = 0
    oldStep = @step
    oldFps = @fps
    @fps = 0
    @step = =>
      @fullChanged()
      @silentMoveBy new Point(xStep, yStep)
      @fullChanged()
      stepCount += 1
      if stepCount is steps
        situation.origin.add @
        situation.origin.reactToDropOf @  if situation.origin.reactToDropOf
        @step = oldStep
        @fps = oldFps
  
  
  # Morph utilities ////////////////////////////////////////////////////////
  
  resize: ->
    @world().activeHandle = new HandleMorph(@)
  
  move: ->
    @world().activeHandle = new HandleMorph(@, null, null, null, null, "move")
  
  hint: (msg) ->
    text = msg
    if msg
      text = msg.toString()  if msg.toString
    else
      text = "NULL"
    m = new MenuMorph(@, text)
    m.isDraggable = true
    m.popUpCenteredAtHand @world()
  
  inform: (msg) ->
    text = msg
    if msg
      text = msg.toString()  if msg.toString
    else
      text = "NULL"
    m = new MenuMorph(@, text)
    m.addItem "Ok"
    m.isDraggable = true
    m.popUpCenteredAtHand @world()

  prompt: (msg, callback, defaultContents, width, floorNum,
    ceilingNum, isRounded) ->
    isNumeric = true  if ceilingNum
    entryField = new StringFieldMorph(
      defaultContents or "",
      width or 100,
      WorldMorph.preferencesAndSettings.prompterFontSize,
      WorldMorph.preferencesAndSettings.prompterFontName,
      false,
      false,
      isNumeric)
    menu = new MenuMorph(@, msg or "", entryField)
    menu.items.push entryField
    if ceilingNum or WorldMorph.preferencesAndSettings.useSliderForInput
      slider = new SliderMorph(
        floorNum or 0,
        ceilingNum,
        parseFloat(defaultContents),
        Math.floor((ceilingNum - floorNum) / 4),
        "horizontal")
      slider.alpha = 1
      slider.color = new Color(225, 225, 225)
      slider.button.color = menu.borderColor
      slider.button.highlightColor = slider.button.color.copy()
      slider.button.highlightColor.b += 100
      slider.button.pressColor = slider.button.color.copy()
      slider.button.pressColor.b += 150
      slider.setHeight WorldMorph.preferencesAndSettings.prompterSliderSize
      if isRounded
        slider.action = (num) ->
          entryField.changed()
          entryField.text.text = Math.round(num).toString()
          entryField.text.updateRendering()
          entryField.text.changed()
          entryField.text.edit()
      else
        slider.action = (num) ->
          entryField.changed()
          entryField.text.text = num.toString()
          entryField.text.updateRendering()
          entryField.text.changed()
      menu.items.push slider
    menu.addLine 2
    menu.addItem "Ok", callback
    #
    menu.addItem "Cancel", ->
      null
    #
    menu.isDraggable = true
    menu.popUpAtHand()
    entryField.text.edit()
  
  pickColor: (msg, callback, defaultContents) ->
    colorPicker = new ColorPickerMorph(defaultContents)
    menu = new MenuMorph(@, msg or "", colorPicker)
    menu.items.push colorPicker
    menu.addLine 2
    menu.addItem "Ok", callback
    #
    menu.addItem "Cancel", ->
      null
    #
    menu.isDraggable = true
    menu.popUpAtHand()

  inspect: (anotherObject) ->
    inspectee = @
    inspectee = anotherObject  if anotherObject
    @spawnInspector inspectee

  spawnInspector: (inspectee) ->
    inspector = new InspectorMorph(inspectee)
    world = (if @world instanceof Function then @world() else (@root() or @world))
    inspector.setPosition world.hand.position()
    inspector.keepWithin world
    world.add inspector
    inspector.changed()
    
  
  # Morph menus ////////////////////////////////////////////////////////////////
  
  contextMenu: ->
    # Spacial multiplexing
    # (search "multiplexing" for the other parts of
    # code where this matters)
    # There are two interpretations of what this
    # list should be:
    #   1) all morphs "pierced through" by the pointer
    #   2) all morphs parents of the topmost morph under the pointer
    # 2 is what is used in Cuis
    
    # commented-out addendum for the implementation of 1):
    #show the normal menu in case there is text selected,
    #otherwise show the spacial multiplexing list
    #if !@world().caret
    #  if @world().hand.allMorphsAtPointer().length > 2
    #    return @hierarchyMenu()
    if @customContextMenu
      return @customContextMenu()
    world = (if @world instanceof Function then @world() else (@root() or @world))
    if world and world.isDevMode
      if @parent is world
        return @developersMenu()
      return @hierarchyMenu()
    @userMenu() or (@parent and @parent.userMenu())
  
  # When user right-clicks on a morph that is a child of other morphs,
  # then it's ambiguous which of the morphs she wants to operate on.
  # An example is right-clicking on a SpeechBubbleMorph: did she
  # mean to operate on the BubbleMorph or did she mean to operate on
  # the TextMorph contained in it?
  # This menu lets her disambiguate.
  hierarchyMenu: ->
    # Spacial multiplexing
    # (search "multiplexing" for the other parts of
    # code where this matters)
    # There are two interpretations of what this
    # list should be:
    #   1) all morphs "pierced through" by the pointer
    #   2) all morphs parents of the topmost morph under the pointer
    # 2 is what is used in Cuis
    # commented-out addendum for the implementation of 1):
    # parents = @world().hand.allMorphsAtPointer().reverse()
    parents = @allParentsTopToBottom()
    world = (if @world instanceof Function then @world() else (@root() or @world))
    menu = new MenuMorph(@, null)
    # show an entry for each of the morphs in the hierarchy.
    # each entry will open the developer menu for each morph.
    parents.forEach (each) ->
      if each.developersMenu and (each isnt world)
        textLabelForMorph = each.toString().slice(0, 50)
        menu.addItem textLabelForMorph, ->
          each.developersMenu().popUpAtHand()
    #  
    menu
  
  developersMenu: ->
    # 'name' is not an official property of a function, hence:
    world = (if @world instanceof Function then @world() else (@root() or @world))
    userMenu = @userMenu() or (@parent and @parent.userMenu())
    menu = new MenuMorph(
      @,
      @constructor.name or @constructor.toString().split(" ")[1].split("(")[0])
    if userMenu
      menu.addItem "user features...", ->
        userMenu.popUpAtHand()
      #
      menu.addLine()
    menu.addItem "color...", (->
      @pickColor menu.title + "\ncolor:", @setColor, @color
    ), "choose another color \nfor this morph"

    menu.addItem "transparency...", (->
      @prompt menu.title + "\nalpha\nvalue:",
        @setAlphaScaled, (@alpha * 100).toString(),
        null,
        1,
        100,
        true
    ), "set this morph's\nalpha value"
    menu.addItem "resize...", (->@resize()), "show a handle\nwhich can be dragged\nto change this morph's" + " extent"
    menu.addLine()
    menu.addItem "duplicate", (->
      aFullCopy = @fullCopy()
      aFullCopy.pickUp()
    ), "make a copy\nand pick it up"
    menu.addItem "pick up", (->@pickUp()), "disattach and put \ninto the hand"
    menu.addItem "attach...", (->@attach()), "stick this morph\nto another one"
    menu.addItem "move", (->@move()), "show a handle\nwhich can be dragged\nto move this morph"
    menu.addItem "inspect", (->@inspect()), "open a window\non all properties"

    # A) normally, just take a picture of this morph
    # and open it in a new tab.
    # B) If a test is being recorded, then the behaviour
    # is slightly different: a system test command is
    # triggered to take a screenshot of this particular
    # morph.
    # C) If a test is being played, then the screenshot of
    # the particular morph is put in a special place
    # in the test player. The command recorded at B) is
    # going to replay but *waiting* for that screenshot
    # first.
    takePic = =>
      if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.RECORDING
        # While recording a test, just trigger for
        # the takeScreenshot command to be recorded. 
        window.world.systemTestsRecorderAndPlayer.takeScreenshot(@)
      else if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.PLAYING
        # While playing a test, this command puts the
        # screenshot of this morph in a special
        # variable of the system test runner.
        # The test runner will wait for this variable
        # to contain the morph screenshot before
        # doing the comparison as per command recorded
        # in the case above.
        window.world.systemTestsRecorderAndPlayer.imageDataOfAParticularMorph = @fullImageData()
      else
        # no system tests recording/playing ongoing,
        # just open new tab with image of morph.
        window.open @fullImageData()
    menu.addItem "take pic", takePic, "open a new window\nwith a picture of this morph"

    menu.addLine()
    if @isDraggable
      menu.addItem "lock", (->@toggleIsDraggable()), "make this morph\nunmovable"
    else
      menu.addItem "unlock", (->@toggleIsDraggable()), "make this morph\nmovable"
    menu.addItem "hide", (->@minimise())
    menu.addItem "delete", (->@destroy())
    menu
  
  userMenu: ->
    null
  
  
  # Morph menu actions
  calculateAlphaScaled: (alpha) ->
    if typeof alpha is "number"
      unscaled = alpha / 100
      return Math.min(Math.max(unscaled, 0.1), 1)
    else
      newAlpha = parseFloat(alpha)
      unless isNaN(newAlpha)
        unscaled = newAlpha / 100
        return Math.min(Math.max(unscaled, 0.1), 1)

  setAlphaScaled: (alphaOrMorphGivingAlpha) ->
    if alphaOrMorphGivingAlpha.getValue?
      alpha = alphaOrMorphGivingAlpha.getValue()
    else
      alpha = alphaOrMorphGivingAlpha
    if alpha
      @alpha = @calculateAlphaScaled(alpha)
      @changed()
  
  attach: ->
    # get rid of any previous temporary
    # active menu because it's meant to be
    # out of view anyways, otherwise we show
    # its overlapping morphs in the options
    # which is most probably not wanted.
    if world.activeMenu
      world.activeMenu = world.activeMenu.destroy()
    choices = world.plausibleTargetAndDestinationMorphs(@)

    # my direct parent might be in the
    # options which is silly, leave that one out
    choicesExcludingParent = []
    choices.forEach (each) =>
      if each != @parent
        choicesExcludingParent.push each

    if choicesExcludingParent.length > 0
      menu = new MenuMorph(@, "choose new parent:")
      choicesExcludingParent.forEach (each) =>
        menu.addItem each.toString().slice(0, 50), =>
          # this is what happens when "each" is
          # selected: we attach the selected morph
          each.add @
          if each instanceof FrameMorph
            each.adjustBounds()
          else
            # you expect Morphs attached
            # inside a FrameMorph
            # to be draggable out of it
            # (as opposed to the content of a ScrollFrameMorph)
            @isDraggable = false
    else
      # the ideal would be to not show the
      # "attach" menu entry at all but for the
      # time being it's quite costly to
      # find the eligible morphs to attach
      # to, so for now let's just calculate
      # this list if the user invokes the
      # command, and if there are no good
      # morphs then show some kind of message.
      menu = new MenuMorph(@, "no morphs to attach to")
    menu.popUpAtHand()
  
  toggleIsDraggable: ->
    # for context menu demo purposes
    @isDraggable = not @isDraggable
  
  colorSetters: ->
    # for context menu demo purposes
    ["color"]
  
  numericalSetters: ->
    # for context menu demo purposes
    ["setLeft", "setTop", "setWidth", "setHeight", "setAlphaScaled"]
  
  
  # Morph entry field tabbing //////////////////////////////////////////////
  
  allEntryFields: ->
    @collectAllChildrenBottomToTopSuchThat (each) ->
      each.isEditable && (each instanceof StringMorph || each instanceof TextMorph);
  
  
  nextEntryField: (current) ->
    fields = @allEntryFields()
    idx = fields.indexOf(current)
    if idx isnt -1
      if fields.length > (idx + 1)
        return fields[idx + 1]
    return fields[0]
  
  previousEntryField: (current) ->
    fields = @allEntryFields()
    idx = fields.indexOf(current)
    if idx isnt -1
      if idx > 0
        return fields[idx - 1]
      return fields[fields.length - 1]
    return fields[0]
  
  tab: (editField) ->
    #
    #	the <tab> key was pressed in one of my edit fields.
    #	invoke my "nextTab()" function if it exists, else
    #	propagate it up my owner chain.
    #
    if @nextTab
      @nextTab editField
    else @parent.tab editField  if @parent
  
  backTab: (editField) ->
    #
    #	the <back tab> key was pressed in one of my edit fields.
    #	invoke my "previousTab()" function if it exists, else
    #	propagate it up my owner chain.
    #
    if @previousTab
      @previousTab editField
    else @parent.backTab editField  if @parent
  
  
  #
  #	the following are examples of what the navigation methods should
  #	look like. Insert these at the World level for fallback, and at lower
  #	levels in the Morphic tree (e.g. dialog boxes) for a more fine-grained
  #	control over the tabbing cycle.
  #
  #Morph.prototype.nextTab = function (editField) {
  #	var	next = this.nextEntryField(editField);
  #	editField.clearSelection();
  #	next.selectAll();
  #	next.edit();
  #};
  #
  #Morph.prototype.previousTab = function (editField) {
  #	var	prev = this.previousEntryField(editField);
  #	editField.clearSelection();
  #	prev.selectAll();
  #	prev.edit();
  #};
  #
  #
  
  # Morph events:
  escalateEvent: (functionName, arg) ->
    handler = @parent
    if handler?
      handler = handler.parent  while not handler[functionName] and handler.parent?
      handler[functionName] arg  if handler[functionName]
  
  
  # Morph eval. Used by the Inspector and the TextMorph.
  evaluateString: (code) ->
    try
      result = eval(code)
      @updateRendering()
      @changed()
    catch err
      @inform err
    result
  
  
  # Morph collision detection - not used anywhere at the moment ////////////////////////
  
  isTouching: (otherMorph) ->
    oImg = @overlappingImage(otherMorph)
    data = oImg.getContext("2d").getImageData(1, 1, oImg.width, oImg.height).data
    detect(data, (each) ->
      each isnt 0
    ) isnt null
  
  overlappingImage: (otherMorph) ->
    fb = @boundsIncludingChildren()
    otherFb = otherMorph.boundsIncludingChildren()
    oRect = fb.intersect(otherFb)
    oImg = newCanvas(oRect.extent().scaleBy pixelRatio)
    ctx = oImg.getContext("2d")
    ctx.scale pixelRatio, pixelRatio
    if oRect.width() < 1 or oRect.height() < 1
      return newCanvas((new Point(1, 1)).scaleBy pixelRatio)
    ctx.drawImage @fullImage(),
      Math.round(oRect.origin.x - fb.origin.x),
      Math.round(oRect.origin.y - fb.origin.y)
    ctx.globalCompositeOperation = "source-in"
    ctx.drawImage otherMorph.fullImage(),
      Math.round(otherFb.origin.x - oRect.origin.x),
      Math.round(otherFb.origin.y - oRect.origin.y)
    oImg

  @coffeeScriptSourceOfThisClass: '''
# Morph //////////////////////////////////////////////////////////////

# A Morph (from the Greek "shape" or "form") is an interactive
# graphical object. General information on the Morphic system
# can be found at http://minnow.cc.gatech.edu/squeak/30. 

# Morphs exist in a tree, rooted at a World or at the Hand.
# The morphs owns submorphs. Morphs are drawn recursively;
# if a Morph has no owner it never gets drawn
# (but note that there are other ways to hide a Morph).

# this comment below is needed to figure our dependencies between classes
# REQUIRES globalFunctions

class Morph extends MorphicNode

  # we want to keep track of how many instances we have
  # of each Morph for a few reasons:
  # 1) it gives us an identifier for each Morph
  # 2) profiling
  # 3) generate a uniqueIDString that we can use
  #    for example for hashtables
  # each subclass of Morph has its own static
  # instancesCounter which starts from zero. First object
  # has instanceNumericID of 1.
  # instanceNumericID is initialised in the constructor.
  @instancesCounter: 0
  # see roundNumericIDsToNextThousand method for an
  # explanation of why we need to keep this extra
  # count
  @lastBuiltInstanceNumericID: 0
  instanceNumericID: 0
  
  # Just some tests here ////////////////////
  propertyUpTheChain: [1,2,3]
  morphMethod: ->
    3.14
  @morphStaticMethod: ->
    3.14
  # End of tests here ////////////////////

  isMorph: true
  bounds: null
  color: null
  texture: null # optional url of a fill-image
  cachedTexture: null # internal cache of actual bg image
  lastTime: null
  alpha: 1

  # for a Morph, being visible and minimised
  # are two separate things.
  # isVisible means that the morph is meant to show
  #  as empty or without any surface. For example
  #  a scrollbar "collapses" itself when there is no
  #  content to scroll and puts its isVisible = false
  # isMinimised means that the morph, whatever its
  #  content or appearance or design, is not drawn
  #  on the desktop. So a minimised or unminimised scrollbar
  #  can be independently either visible or not.
  # If we merge the two flags into one, then the
  # following happens: "hiding" a morph causes the
  # scrollbars in it to hide. Unhiding it causes the
  # scrollbars to show, even if they should be invisible.
  # Hence the need of two separate flags.
  # Also, it's semantically two
  # separate reasons of why a morph is not being
  # painted on screen, so it makes sense to have
  # two separate flags.
  isMinimised: false
  isVisible: true

  isDraggable: false
  isTemplate: false
  acceptsDrops: false
  noticesTransparentClick: false
  fps: 0
  customContextMenu: null
  trackChanges: true
  shadowBlur: 10
  # note that image contains only the CURRENT morph, not the composition of this
  # morph with all of the submorphs. I.e. for an inspector, this will only
  # contain the background of the window pane. Not any of its contents.
  # for the worldMorph, this only contains the background
  image: null
  onNextStep: null # optional function to be run once. Not currently used in Zombie Kernel

  # contains all the reactive vals
  allValsInMorphByName: null
  morphValsDependingOnChildrenVals: null
  morphValsDirectlyDependingOnParentVals: null

  ##########################################################
  # These two methods are for mixins
  ##########################################################
  # adds class properties
  @augmentWith: (obj) ->
    for key, value of obj when key not in MixedClassKeywords
      @[key] = value
    obj.onceAddedClassProperties?.apply(@)
    this

  # adds instance properties
  @addInstanceProperties: (obj) ->
    for key, value of obj when key not in MixedClassKeywords
      # Assign properties to the prototype
      @::[key] = value
    obj.included?.apply(@)
    this
  ################# end of mixins methods ##################

  ##########################################################
  # Reactive Values start
  ##########################################################


  connectValuesToAddedChild: (theChild) ->
    #if theChild.constructor.name == "RectangleMorph"
    #  debugger

    # we have a data structure that contains,
    # for each child valName, all vals of this
    # morph that depend on it. Go through
    # all child val names, find the
    # actual val in the child, and connect all
    # to the vals in this morph that depend on it.
    for nameOfChildrenVar, morphValsDependingOnChildrenVals of \
        @morphValsDependingOnChildrenVals
      childVal = theChild.allValsInMorphByName[ nameOfChildrenVar ]
      if childVal?
        for valNameNotUsed, valDependingOnChildrenVal of morphValsDependingOnChildrenVals
          valDependingOnChildrenVal.args.connectToChildVal valDependingOnChildrenVal, childVal

    # we have a data structure that contains,
    # for each parent (me) valName, all vals of the child
    # morph that depend on it. Go through
    # all parent (me) val names, find the
    # actual val in the parent (me), and connect it
    # to the vals in the child morph that depend on it.
    for nameOfParentVar, morphValsDirectlyDependingOnParentVals of \
        theChild.morphValsDirectlyDependingOnParentVals
      parentVal = @allValsInMorphByName[ nameOfParentVar ]
      if parentVal?
        for valNameNotUsed, valDependingOnParentVal of morphValsDirectlyDependingOnParentVals
          valDependingOnParentVal.args.connectToParentVal valDependingOnParentVal, parentVal

  disconnectValuesFromRemovedChild: (theChild) ->
    # we have a data structure that contains,
    # for each child valName, all vals of this
    # morph that depend on it. Go through
    # all child val names, find the
    # actual val in the child, and DISconnect it
    # FROM the vals in this morph that depended on it.
    for nameOfChildrenVar, morphValsDependingOnChildrenVals of \
        @morphValsDependingOnChildrenVals
      for valNameNotUsed, valDependingOnChildrenVal of morphValsDependingOnChildrenVals
        childArg = valDependingOnChildrenVal.args.argById[theChild.id]
        if childArg?
          childArg.disconnectChildArg()

    # we have a data structure that contains,
    # for each parent (me) valName, all vals of the child
    # morph that depend on it. Go through
    # all parent (me) val names, find the
    # actual val in the parent (me), and connect it
    # to the vals in the child morph that depend on it.
    for nameOfParentVar, morphValsDirectlyDependingOnParentVals of \
        theChild.morphValsDirectlyDependingOnParentVals
      for valNameNotUsed, valDependingOnParentVal of morphValsDirectlyDependingOnParentVals
        parentArg = valDependingOnParentVal.args.parentArgByName[ nameOfParentVar ]
        if parentArg?
          parentArg.disconnectParentArg()


  ############## end of reactive values ##########################

  uniqueIDString: ->
    @morphClassString() + "#" + @instanceNumericID

  morphClassString: ->
    (@constructor.name or @constructor.toString().split(" ")[1].split("(")[0])

  @morphFromUniqueIDString: (theUniqueID) ->
    result = world.topMorphSuchThat (m) =>
      m.uniqueIDString() is theUniqueID
    if not result?
      alert "theUniqueID " + theUniqueID + " not found!"
    return result

  assignUniqueID: ->
    @constructor.instancesCounter++
    @constructor.lastBuiltInstanceNumericID++
    @instanceNumericID = @constructor.lastBuiltInstanceNumericID

  # some test commands specify morphs via
  # their uniqueIDString. This means that
  # if there is one more TextMorph anywhere during
  # the playback, for example because
  # one new menu item is added, then
  # all the subsequent IDs for the TextMorph will be off.
  # In order to sort that out, we occasionally re-align
  # the counts to the next 1000, so the next Morphs
  # being created will all be aligned and
  # minor discrepancies are ironed-out
  @roundNumericIDsToNextThousand: ->
    console.log "@roundNumericIDsToNextThousand"
    # this if is because zero and multiples of 1000
    # don't go up to 1000
    if @lastBuiltInstanceNumericID %1000 == 0
      @lastBuiltInstanceNumericID++
    @lastBuiltInstanceNumericID = 1000*Math.ceil(@lastBuiltInstanceNumericID/1000)

  constructor: ->
    super()
    @assignUniqueID()

    # [TODO] why is there this strange non-zero default bound?
    @bounds = new Rectangle(0, 0, 50, 40)
    @color = @color or new Color(80, 80, 80)
    @lastTime = Date.now()
    # Note that we don't call @updateRendering()
    # that's because the actual extending morph will probably
    # set more details of how it should look (e.g. size),
    # so we wait and we let the actual extending
    # morph to draw itself.

    @allValsInMorphByName = {}
    @morphValsDependingOnChildrenVals = {}
    @morphValsDirectlyDependingOnParentVals = {}


  
  #
  #    damage list housekeeping
  #
  #	the trackChanges property of the Morph prototype is a Boolean switch
  #	that determines whether the World's damage list ('broken' rectangles)
  #	tracks changes. By default the switch is always on. If set to false
  #	changes are not stored. This can be very useful for housekeeping of
  #	the damage list in situations where a large number of (sub-) morphs
  #	are changed more or less at once. Instead of keeping track of every
  #	single submorph's changes tremendous performance improvements can be
  #	achieved by setting the trackChanges flag to false before propagating
  #	the layout changes, setting it to true again and then storing the full
  #	bounds of the surrounding morph. An an example refer to the
  #
  #		layoutSubmorphs()
  #		
  #	method of InspectorMorph, or the
  #	
  #		startLayout()
  #		endLayout()
  #
  #	methods of SyntaxElementMorph in the Snap application.
  #
  
  
  # Morph string representation: e.g. 'a Morph#2 [20@45 | 130@250]'
  toString: ->
    firstPart = "a "

    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.hidingOfMorphsNumberIDInLabels
      firstPart = firstPart + @morphClassString()
    else
      firstPart = firstPart + @uniqueIDString()

    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.hidingOfMorphsGeometryInfoInLabels
      return firstPart
    else
      return firstPart + " " + @bounds

  # Morph string representation: e.g. 'a Morph#2'
  toStringWithoutGeometry: ->
    "a " +
      @uniqueIDString()
  
  
  # Morph deleting:
  destroy: ->
    # todo there is something to be figured out here
    # cause in theory ALL the morphs in here are not
    # visible, not just the parent... but it kind of
    # seems overkill...
    @visible = false
    if @parent?
      @fullChanged()
      @parent.removeChild @
    return null
  
  destroyAll: ->
    # we can't use forEach because we are iterating over
    # an array that changes its values (and length) while
    # we are iterating on it.
    until @children.length == 0
      @children[0].destroy()
    return null

  # Morph stepping:
  runChildrensStepFunction: ->
    # step is the function that this Morph wants to run at each step.
    # If the Morph wants to do nothing and let no-one of the children do nothing,
    # then step is set to null.
    # If the morph wants to do nothing but the children might want to do something,
    # then step is set to the function that does nothing (i.e. a function noOperation that
    # only returns null) 
    return null  unless @step

    # for objects where @fps is defined, check which ones are due to be stepped
    # and which ones want to wait. 
    elapsed = WorldMorph.currentTime - @lastTime
    if @fps > 0
      timeRemainingToWaitedFrame = (1000 / @fps) - elapsed
    else
      timeRemainingToWaitedFrame = 0
    
    # Question: why 1 here below?
    if timeRemainingToWaitedFrame < 1
      @lastTime = WorldMorph.currentTime
      if @onNextStep
        nxt = @onNextStep
        @onNextStep = null
        nxt.call(@)
      @step()
      @children.forEach (child) ->
        child.runChildrensStepFunction()

  # not used within Zombie Kernel yet.
  nextSteps: (arrayOfFunctions) ->
    lst = arrayOfFunctions or []
    nxt = lst.shift()
    if nxt
      @onNextStep = =>
        nxt.call @
        @nextSteps lst  
  
  # leaving this function as step means that the morph wants to do nothing
  # but the children *are* traversed and their step function is invoked.
  # If a Morph wants to do nothing and wants to prevent the children to be
  # traversed, then this function should be set to null.
  step: noOperation
  
  
  # Morph accessing - geometry getting:
  left: ->
    @bounds.left()
  
  right: ->
    @bounds.right()
  
  top: ->
    @bounds.top()
  
  bottom: ->
    @bounds.bottom()
  
  center: ->
    @bounds.center()
  
  bottomCenter: ->
    @bounds.bottomCenter()
  
  bottomLeft: ->
    @bounds.bottomLeft()
  
  bottomRight: ->
    @bounds.bottomRight()
  
  boundingBox: ->
    @bounds
  
  corners: ->
    @bounds.corners()
  
  leftCenter: ->
    @bounds.leftCenter()
  
  rightCenter: ->
    @bounds.rightCenter()
  
  topCenter: ->
    @bounds.topCenter()
  
  topLeft: ->
    @bounds.topLeft()
  
  topRight: ->
    @bounds.topRight()
  
  position: ->
    @bounds.origin
  
  extent: ->
    @bounds.extent()
  
  width: ->
    @bounds.width()
  
  height: ->
    @bounds.height()


  # used for example:
  # - to determine which morphs you can attach a morph to
  # - for a SliderMorph's "set target" so you can change properties of another Morph
  # - by the HandleMorph when you attach it to some other morph
  # Note that this method has a slightly different
  # version in FrameMorph (because it clips, so we need
  # to check that we don't consider overlaps with
  # morphs contained in a frame that are clipped and
  # hence *actually* not overlapping).
  plausibleTargetAndDestinationMorphs: (theMorph) ->
    # find if I intersect theMorph,
    # then check my children recursively
    # exclude me if I'm a child of theMorph
    # (cause it's usually odd to attach a Morph
    # to one of its submorphs or for it to
    # control the properties of one of its submorphs)
    result = []
    if !@isMinimised and
        @isVisible and
        !theMorph.containedInParentsOf(@) and
        @bounds.intersects(theMorph.bounds)
      result = [@]

    @children.forEach (child) ->
      result = result.concat(child.plausibleTargetAndDestinationMorphs(theMorph))

    return result

  
  boundsIncludingChildren: ->
    result = @bounds
    @children.forEach (child) ->
      if !child.isMinimised and child.isVisible
        result = result.merge(child.boundsIncludingChildren())
    result
  
  boundsIncludingChildrenNoShadow: ->
    # answer my full bounds but ignore any shadow
    result = @bounds
    @children.forEach (child) ->
      if (child not instanceof ShadowMorph) and (!child.isMinimised) and (child.isVisible)
        result = result.merge(child.boundsIncludingChildrenNoShadow())
    result
  
  visibleBounds: ->
    # answer which part of me is not clipped by a Frame
    visible = @bounds
    frames = @allParentsTopToBottomSuchThat (p) ->
      p instanceof FrameMorph
    frames.forEach (f) ->
      visible = visible.intersect(f.bounds)
    #
    visible
  
  
  # Morph accessing - simple changes:
  moveBy: (delta) ->
    # note that changed() is called two times
    # because there are two areas of the screens
    # that are dirty: the starting
    # position and the end position.
    # Both need to be repainted.
    @changed()
    @bounds = @bounds.translateBy(delta)
    @children.forEach (child) ->
      child.moveBy delta
    #
    @changed()
  
  silentMoveBy: (delta) ->
    @bounds = @bounds.translateBy(delta)
    @children.forEach (child) ->
      child.silentMoveBy delta
  
  
  setPosition: (aPoint) ->
    delta = aPoint.subtract(@topLeft())
    @moveBy delta  if (delta.x isnt 0) or (delta.y isnt 0)
  
  silentSetPosition: (aPoint) ->
    delta = aPoint.subtract(@topLeft())
    @silentMoveBy delta  if (delta.x isnt 0) or (delta.y isnt 0)
  
  setLeft: (x) ->
    @setPosition new Point(x, @top())
  
  setRight: (x) ->
    @setPosition new Point(x - @width(), @top())
  
  setTop: (y) ->
    @setPosition new Point(@left(), y)
  
  setBottom: (y) ->
    @setPosition new Point(@left(), y - @height())
  
  setCenter: (aPoint) ->
    @setPosition aPoint.subtract(@extent().floorDivideBy(2))
  
  setFullCenter: (aPoint) ->
    @setPosition aPoint.subtract(@boundsIncludingChildren().extent().floorDivideBy(2))
  
  # make sure I am completely within another Morph's bounds
  keepWithin: (aMorph) ->
    leftOff = @boundsIncludingChildren().left() - aMorph.left()
    @moveBy new Point(-leftOff, 0)  if leftOff < 0
    rightOff = @boundsIncludingChildren().right() - aMorph.right()
    @moveBy new Point(-rightOff, 0)  if rightOff > 0
    topOff = @boundsIncludingChildren().top() - aMorph.top()
    @moveBy new Point(0, -topOff)  if topOff < 0
    bottomOff = @boundsIncludingChildren().bottom() - aMorph.bottom()
    @moveBy new Point(0, -bottomOff)  if bottomOff > 0
  
  # the default of layoutSubmorphs
  # is to do nothing, but things like
  # the inspector might well want to
  # tweak many of theor children...
  layoutSubmorphs: ->
    null
  
  # Morph accessing - dimensional changes requiring a complete redraw
  setExtent: (aPoint) ->
    # check whether we are actually changing the extent.
    unless aPoint.eq(@extent())
      @changed()
      @silentSetExtent aPoint
      @changed()
      @updateRendering()
      @layoutSubmorphs()
  
  silentSetExtent: (aPoint) ->
    ext = aPoint.round()
    newWidth = Math.max(ext.x, 0)
    newHeight = Math.max(ext.y, 0)
    @bounds.corner = new Point(@bounds.origin.x + newWidth, @bounds.origin.y + newHeight)
  
  setWidth: (width) ->
    @setExtent new Point(width or 0, @height())
  
  silentSetWidth: (width) ->
    # do not updateRendering() just yet
    w = Math.max(Math.round(width or 0), 0)
    @bounds.corner = new Point(@bounds.origin.x + w, @bounds.corner.y)
  
  setHeight: (height) ->
    @setExtent new Point(@width(), height or 0)
  
  silentSetHeight: (height) ->
    # do not updateRendering() just yet
    h = Math.max(Math.round(height or 0), 0)
    @bounds.corner = new Point(@bounds.corner.x, @bounds.origin.y + h)
  
  setColor: (aColorOrAMorphGivingAColor) ->
    if aColorOrAMorphGivingAColor.getColor?
      aColor = aColorOrAMorphGivingAColor.getColor()
    else
      aColor = aColorOrAMorphGivingAColor
    if aColor
      unless @color.eq(aColor)
        @color = aColor
        @changed()
        @updateRendering()
  
  
  # Morph displaying ###########################################################

  # There are three fundamental methods for rendering and displaying anything.
  # * updateRendering: this one creates/updates the local canvas of this morph only
  #   i.e. not the children. For example: a ColorPickerMorph is a Morph which
  #   contains three children Morphs (a color palette, a greyscale palette and
  #   a feedback). The updateRendering method of ColorPickerMorph only creates
  #   a canvas for the container Morph. So that's just a canvas with a
  #   solid color. As the
  #   ColorPickerMorph constructor runs, the three childredn Morphs will
  #   run their own updateRendering method, so each child will have its own
  #   canvas with their own contents.
  #   Note that updateRendering should be called sparingly. A morph should repaint
  #   its buffer pretty much only *after* it's been added to itf first parent and
  #   whenever it changes dimensions. Things like changing parent and updating
  #   the position shouldn't normally trigger an update of the buffer.
  #   Also note that before the buffer is painted for the first time, they
  #   might not know their extent. Typically text-related Morphs know their
  #   extensions after they painted the text for the first time...
  # * blit: takes the local canvas and blits it to a specific area in a passed
  #   canvas. The local canvas doesn't contain any rendering of the children of
  #   this morph.
  # * recursivelyBlit: recursively draws all the local canvas of this morph and all
  #   its children into a specific area of a passed canvas.

  updateRendering: ->
    # initialize my surface property
    @image = newCanvas(@extent().scaleBy pixelRatio)
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    context.fillStyle = @color.toString()
    context.fillRect 0, 0, @width(), @height()
    if @cachedTexture
      @drawCachedTexture()
    else @drawTexture @texture  if @texture
    @changed()
  
  drawTexture: (url) ->
    @cachedTexture = new Image()
    @cachedTexture.onload = =>
      @drawCachedTexture()
    #
    @cachedTexture.src = @texture = url # make absolute
  
  # tiles the texture
  drawCachedTexture: ->
    bg = @cachedTexture
    cols = Math.floor(@image.width / bg.width)
    lines = Math.floor(@image.height / bg.height)
    context = @image.getContext("2d")
    for y in [0..lines]
      for x in [0..cols]
        context.drawImage bg, Math.round(x * bg.width), Math.round(y * bg.height)
    @changed()
  
  
  #
  #Morph.prototype.drawCachedTexture = function () {
  #    var context = this.image.getContext('2d'),
  #        pattern = context.createPattern(this.cachedTexture, 'repeat');
  #	context.fillStyle = pattern;
  #    context.fillRect(0, 0, this.image.width, this.image.height);
  #    this.changed();
  #};
  #
  
  # This method only paints this very morph's "image",
  # it doesn't descend the children
  # recursively. The recursion mechanism is done by recursivelyBlit, which
  # eventually invokes blit.
  # Note that this morph might paint something on the screen even if
  # it's not a "leaf".
  blit: (aCanvas, clippingRectangle) ->
    return null  if @isMinimised or !@isVisible or !@image?
    area = clippingRectangle.intersect(@bounds).round()
    # test whether anything that we are going to be drawing
    # is visible (i.e. within the clippingRectangle)
    if area.isNotEmpty()
      delta = @position().neg()
      src = area.copy().translateBy(delta).round()
      context = aCanvas.getContext("2d")
      context.globalAlpha = @alpha
      sl = src.left() * pixelRatio
      st = src.top() * pixelRatio
      al = area.left() * pixelRatio
      at = area.top() * pixelRatio
      w = Math.min(src.width() * pixelRatio, @image.width - sl)
      h = Math.min(src.height() * pixelRatio, @image.height - st)
      return null  if w < 1 or h < 1

      context.drawImage @image,
        Math.round(sl),
        Math.round(st),
        Math.round(w),
        Math.round(h),
        Math.round(al),
        Math.round(at),
        Math.round(w),
        Math.round(h)

      if world.showRedraws
        randomR = Math.round(Math.random()*255)
        randomG = Math.round(Math.random()*255)
        randomB = Math.round(Math.random()*255)
        context.globalAlpha = 0.5
        context.fillStyle = "rgb("+randomR+","+randomG+","+randomB+")";
        context.fillRect(Math.round(al),Math.round(at),Math.round(w),Math.round(h));
  
  
  # "for debugging purposes:"
  #
  #		try {
  #			context.drawImage(
  #				this.image,
  #				src.left(),
  #				src.top(),
  #				w,
  #				h,
  #				area.left(),
  #				area.top(),
  #				w,
  #				h
  #			);
  #		} catch (err) {
  #			alert('internal error\n\n' + err
  #				+ '\n ---'
  #				+ '\n canvas: ' + aCanvas
  #				+ '\n canvas.width: ' + aCanvas.width
  #				+ '\n canvas.height: ' + aCanvas.height
  #				+ '\n ---'
  #				+ '\n image: ' + this.image
  #				+ '\n image.width: ' + this.image.width
  #				+ '\n image.height: ' + this.image.height
  #				+ '\n ---'
  #				+ '\n w: ' + w
  #				+ '\n h: ' + h
  #				+ '\n sl: ' + sl
  #				+ '\n st: ' + st
  #				+ '\n area.left: ' + area.left()
  #				+ '\n area.top ' + area.top()
  #				);
  #		}
  #	
  recursivelyBlit: (aCanvas, clippingRectangle = @boundsIncludingChildren()) ->
    return null  if @isMinimised or !@isVisible

    # in general, the children of a Morph could be outside the
    # bounds of the parent (they could also be much larger
    # then the parent). This means that we have to traverse
    # all the children to find out whether any of those overlap
    # the clipping rectangle. Note that we can be smarter with
    # FrameMorphs, as their children are actually all contained
    # within the parent's boundary.

    # Note that if we could dynamically and cheaply keep an updated
    # boundsIncludingChildren property, then we could be smarter
    # in discarding whole sections of the scene graph.
    # (see https://github.com/davidedc/Zombie-Kernel/issues/150 )

    @blit aCanvas, clippingRectangle
    @children.forEach (child) ->
      child.recursivelyBlit aCanvas, clippingRectangle
  

  hide: ->
    @isVisible = false
    @changed()
    @children.forEach (child) ->
      child.hide()

  show: ->
    @isVisible = true
    @changed()
    @children.forEach (child) ->
      child.show()
  
  minimise: ->
    @isMinimised = true
    @changed()
    @children.forEach (child) ->
      child.minimise()
  
  unminimise: ->
    @isMinimised = false
    @changed()
    @children.forEach (child) ->
      child.unminimise()
  
  
  toggleVisibility: ->
    @isMinimised = (not @isMinimised)
    @changed()
    @children.forEach (child) ->
      child.toggleVisibility()
  
  
  # Morph full image:
  
  # Fixes https://github.com/jmoenig/morphic.js/issues/7
  # and https://github.com/davidedc/Zombie-Kernel/issues/160
  fullImage: ->
    boundsIncludingChildren = @boundsIncludingChildren()
    img = newCanvas(boundsIncludingChildren.extent().scaleBy pixelRatio)
    ctx = img.getContext("2d")
    # ctx.scale pixelRatio, pixelRatio
    # we are going to draw this morph and its children into "img".
    # note that the children are not necessarily geometrically
    # contained in the morph (in which case it would be ok to
    # translate the context so that the origin of *this* morph is
    # at the top-left of the "img" canvas).
    # Hence we have to translate the context
    # so that the origin of the entire boundsIncludingChildren is at the
    # very top-left of the "img" canvas.
    ctx.translate -boundsIncludingChildren.origin.x * pixelRatio , -boundsIncludingChildren.origin.y * pixelRatio
    @recursivelyBlit img, boundsIncludingChildren
    img

  fullImageData: ->
    # returns a string like "data:image/png;base64,iVBORw0KGgoAA..."
    # note that "image/png" below could be omitted as it's
    # the default, but leaving it here for clarity.
    @fullImage().toDataURL("image/png")

  fullImageHashCode: ->
    return hashCode(@fullImageData())
  
  # Morph shadow:
  shadowImage: (off_, color) ->
    # fallback for Windows Chrome-Shadow bug
    offset = off_ or new Point(7, 7)
    clr = color or new Color(0, 0, 0)
    fb = @boundsIncludingChildren().extent()
    img = @fullImage()
    outline = newCanvas(fb.scaleBy pixelRatio)
    ctx = outline.getContext("2d")
    #ctx.scale pixelRatio, pixelRatio
    ctx.drawImage img, 0, 0
    ctx.globalCompositeOperation = "destination-out"
    ctx.drawImage img, Math.round(-offset.x) * pixelRatio, Math.round(-offset.y) * pixelRatio
    sha = newCanvas(fb.scaleBy pixelRatio)
    ctx = sha.getContext("2d")
    #ctx.scale pixelRatio, pixelRatio
    ctx.drawImage outline, 0, 0
    ctx.globalCompositeOperation = "source-atop"
    ctx.fillStyle = clr.toString()
    ctx.fillRect 0, 0, fb.x * pixelRatio, fb.y * pixelRatio
    sha
  
  # the one used right now
  shadowImageBlurred: (off_, color) ->
    offset = off_ or new Point(7, 7)
    blur = @shadowBlur
    clr = color or new Color(0, 0, 0)
    fb = @boundsIncludingChildren().extent().add(blur * 2)
    img = @fullImage()
    sha = newCanvas(fb.scaleBy pixelRatio)
    ctx = sha.getContext("2d")
    #ctx.scale pixelRatio, pixelRatio
    ctx.shadowOffsetX = offset.x * pixelRatio
    ctx.shadowOffsetY = offset.y * pixelRatio
    ctx.shadowBlur = blur * pixelRatio
    ctx.shadowColor = clr.toString()
    ctx.drawImage img, Math.round((blur - offset.x)*pixelRatio), Math.round((blur - offset.y)*pixelRatio)
    ctx.shadowOffsetX = 0
    ctx.shadowOffsetY = 0
    ctx.shadowBlur = 0
    ctx.globalCompositeOperation = "destination-out"
    ctx.drawImage img, Math.round((blur - offset.x)*pixelRatio), Math.round((blur - offset.y)*pixelRatio)
    sha
  
  
  # shadow is added to a morph by
  # the HandMorph while dragging
  addShadow: (offset, alpha, color) ->
    shadow = new ShadowMorph(@, offset, alpha, color)
    @addBack shadow
    @fullChanged()
    shadow
  
  getShadow: ->
    return @topmostChildSuchThat (child) ->
      child instanceof ShadowMorph
  
  removeShadow: ->
    shadow = @getShadow()
    if shadow?
      @fullChanged()
      @removeChild shadow
  
  
  # Morph pen trails:
  penTrails: ->
    # answer my pen trails canvas. default is to answer my image
    # The implication is that by default every Morph in the system
    # (including the World) is able to act as turtle canvas and can
    # display pen trails.
    # BUT also this means that pen trails will be lost whenever
    # the trail's morph (the pen's parent) performs a "drawNew()"
    # operation. If you want to create your own pen trails canvas,
    # you may wish to modify its **penTrails()** property, so that
    # it keeps a separate offscreen canvas for pen trails
    # (and doesn't lose these on redraw).
    @image
  
  
  # Morph updating ///////////////////////////////////////////////////////////////
  changed: ->
    if @trackChanges
      w = @root()
      # unless we are the main desktop, then if the morph has no parent
      # don't add the broken rect since the morph is not visible
      if w instanceof WorldMorph and (@ instanceof WorldMorph or @parent?)
        w.broken.push @visibleBounds().spread()
    @parent.childChanged @  if @parent
  
  fullChanged: ->
    if @trackChanges
      w = @root()
      # unless we are the main desktop, then if the morph has no parent
      # don't add the broken rect since the morph is not visible
      if w instanceof WorldMorph and ((@ instanceof WorldMorph or @parent?))
        w.broken.push @boundsIncludingChildren().spread()
  
  childChanged: ->
    # react to a  change in one of my children,
    # default is to just pass this message on upwards
    # override this method for Morphs that need to adjust accordingly
    @parent.childChanged @  if @parent
  
  
  # Morph accessing - structure //////////////////////////////////////////////
  world: ->
    root = @root()
    return root  if root instanceof WorldMorph
    return root.world  if root instanceof HandMorph
    null
  
  # attaches submorph on top
  # ??? TODO you should handle the case of Morph
  #     being added to itself and the case of
  # ??? TODO a Morph being added to one of its
  #     children
  add: (aMorph) ->
    # the morph that is being
    # attached might be attached to
    # a clipping morph. So we
    # need to do a "changed" here
    # to make sure that anything that
    # is outside the clipping Morph gets
    # painted over.
    aMorph.changed()
    owner = aMorph.parent
    owner.removeChild aMorph  if owner?
    @addChild aMorph
    aMorph.updateRendering()
  
  # attaches submorph underneath
  addBack: (aMorph) ->
    owner = aMorph.parent
    owner.removeChild aMorph  if owner?
    aMorph.updateRendering()
    # this is a curious instance where
    # we first update the rendering and then
    # we add the morph. This is because
    # the rendering depends on the
    # full extent including children of
    # the morph we are attaching the shadow
    # to. So if we add the shadow we are going
    # to influence those measurements and
    # make our life very difficult for
    # ourselves.
    @addChildFirst aMorph
  

  # never currently used in ZK
  # TBD whether this is 100% correct,
  # see "topMorphUnderPointer" implementation in
  # HandMorph.
  # Also there must be a quicker implementation
  # cause there is no need to create the entire
  # morph list. It would be sufficient to
  # navigate the structure and just return
  # at the first morph satisfying the test.
  morphAt: (aPoint) ->
    morphs = @allChildrenTopToBottom()
    result = null
    morphs.forEach (m) ->
      if m.boundsIncludingChildren().containsPoint(aPoint) and (result is null)
        result = m
    #
    result
  
  #
  #	potential alternative - solution for morphAt.
  #	Has some issues, commented out for now...
  #
  #Morph.prototype.morphAt = function (aPoint) {
  #	return this.topMorphSuchThat(function (m) {
  #		return m.boundsIncludingChildren().containsPoint(aPoint);
  #	});
  #};
  #
  
  # Morph pixel access:
  getPixelColor: (aPoint) ->
    point = aPoint.subtract(@bounds.origin)
    context = @image.getContext("2d")
    data = context.getImageData(point.x * pixelRatio, point.y * pixelRatio, 1, 1)
    new Color(data.data[0], data.data[1], data.data[2], data.data[3])
  
  isTransparentAt: (aPoint) ->
    if @bounds.containsPoint(aPoint)
      return false  if @texture
      point = aPoint.subtract(@bounds.origin)
      context = @image.getContext("2d")
      data = context.getImageData(Math.floor(point.x)*pixelRatio, Math.floor(point.y)*pixelRatio, 1, 1)
      # check the 4th byte - the Alpha (RGBA)
      return data.data[3] is 0
    false
  
  # Morph duplicating ////////////////////////////////////////////////////

  # creates a new instance of target's type
  clone: (target) ->
    #alert "cloning a " + target.constructor.name
    if typeof target is "object"
      # note that the constructor method is not run!
      theClone = Object.create(target.constructor.prototype)
      #console.log "theClone class:" + theClone.constructor.name
      theClone.assignUniqueID()
      #theClone.constructor()
      return theClone
    target

  # returns a shallow copy of target.
  # Shallow copy keeps references to original objects, arrays or functions
  # within the new object, so the “copy” is still linked to the original
  # object. In other words, they will be pointing to the same memory
  # location. String and Numbers are duplicated instead.
  shallowCopy: (target) ->
    c = @clone(target.constructor::)
    for property of target
      # there are a couple of properties that we don't want to copy over...
      if target.hasOwnProperty(property) and property != "instanceNumericID"
        c[property] = target[property]
        #if target.constructor.name == "SliderMorph"
        #  alert "copying property: " + property
    c
  
  copy: ->
    c = @shallowCopy(@)
    c.parent = null
    c.children = []
    c.bounds = @bounds.copy()
    c
  
  copyRecordingReferences: (dict) ->
    # copies a Morph, its properties and its submorphs. Properties
    # are shallow-copied, so for example Numbers and Strings
    # are actually duplicated,
    # but arrays objects and functions are not deep-copied i.e.
    # just the references are copied.
    # Also builds a correspondence of the morph and its submorphs to their
    # respective clones.

    c = @copy()
    # "dict" maps the correspondences from this object to the
    # copy one. So dict[propertyOfThisObject] = propertyOfCopyObject
    dict[@uniqueIDString()] = c
    @children.forEach (m) ->
      # the result of this loop is that all the children of this
      # object are (recursively) copied and attached to the copy of this
      # object. dict will contain all the mappings between the
      # children of this object and the copied children.
      c.add m.copyRecordingReferences(dict)
    c
  
  fullCopy: ->
    #
    #	Produce a copy of me with my entire tree of submorphs. Morphs
    #	mentioned more than once are all directed to a single new copy.
    #	Other properties are also *shallow* copied, so you must override
    #	to deep copy Arrays and (complex) Objects
    #	
    #alert "doing a full copy"
    dict = {}
    c = @copyRecordingReferences(dict)
    # note that child.updateReferences is invoked
    # from the bottom up, i.e. from the leaf children up to the
    # parents. This is important because it means that each
    # child can properly fix the connections between the "mapped"
    # children correctly.
    #alert "### updating references"
    #alert "number of children: " + c.children.length
    c.forAllChildrenBottomToTop (child) ->
      #alert ">>> updating reference of " + child
      child.updateReferences dict
    #alert ">>> updating reference of " + c
    c.updateReferences dict
    #
    c
  
  # if the constructor of the object you are copying performs
  # some complex building and connecting of the elements,
  # and there are some callbacks around,
  # then maybe you could need to override this method.
  # The inspectorMorph needed to override this method
  # until extensive refactoring was performed.
  updateReferences: (dict) ->
    #
    #	Update intra-morph references within a composite morph that has
    #	been copied. For example, if a button refers to morph X in the
    #	orginal composite then the copy of that button in the new composite
    #	should refer to the copy of X in new composite, not the original X.
    # This is done via scanning all the properties of the object and
    # checking whether any of those has a mapping. If so, then it is
    # replaced with its mapping.
    #	
    #alert "updateReferences of " + @toString()
    for property of @
      if @[property]?
        #if property == "button"
        #  alert "!! property: " + property + " is morph: " + (@[property]).isMorph
        #  alert "dict[property]: " + dict[(@[property]).uniqueIDString()]
        if (@[property]).isMorph and dict[(@[property]).uniqueIDString()]
          #if property == "button"
          #  alert "!! updating property: " + property + " to: " + dict[(@[property]).uniqueIDString()]
          @[property] = dict[(@[property]).uniqueIDString()]
  
  
  # Morph dragging and dropping /////////////////////////////////////////
  
  rootForGrab: ->
    if @ instanceof ShadowMorph
      return @parent.rootForGrab()
    if @parent instanceof ScrollFrameMorph
      return @parent
    if @parent is null or
      @parent instanceof WorldMorph or
      @parent instanceof FrameMorph or
      @isDraggable is true
        return @  
    @parent.rootForGrab()
  
  wantsDropOf: (aMorph) ->
    # default is to answer the general flag - change for my heirs
    if (aMorph instanceof HandleMorph) or
      (aMorph instanceof MenuMorph)
        return false  
    @acceptsDrops
  
  pickUp: ->
    @setPosition world.hand.position().subtract(@extent().floorDivideBy(2))
    world.hand.grab @
  
  isPickedUp: ->
    @parentThatIsA(HandMorph)?
  
  situation: ->
    # answer a dictionary specifying where I am right now, so
    # I can slide back to it if I'm dropped somewhere else
    if @parent
      return (
        origin: @parent
        position: @position().subtract(@parent.position())
      )
    null
  
  slideBackTo: (situation, inSteps) ->
    steps = inSteps or 5
    pos = situation.origin.position().add(situation.position)
    xStep = -(@left() - pos.x) / steps
    yStep = -(@top() - pos.y) / steps
    stepCount = 0
    oldStep = @step
    oldFps = @fps
    @fps = 0
    @step = =>
      @fullChanged()
      @silentMoveBy new Point(xStep, yStep)
      @fullChanged()
      stepCount += 1
      if stepCount is steps
        situation.origin.add @
        situation.origin.reactToDropOf @  if situation.origin.reactToDropOf
        @step = oldStep
        @fps = oldFps
  
  
  # Morph utilities ////////////////////////////////////////////////////////
  
  resize: ->
    @world().activeHandle = new HandleMorph(@)
  
  move: ->
    @world().activeHandle = new HandleMorph(@, null, null, null, null, "move")
  
  hint: (msg) ->
    text = msg
    if msg
      text = msg.toString()  if msg.toString
    else
      text = "NULL"
    m = new MenuMorph(@, text)
    m.isDraggable = true
    m.popUpCenteredAtHand @world()
  
  inform: (msg) ->
    text = msg
    if msg
      text = msg.toString()  if msg.toString
    else
      text = "NULL"
    m = new MenuMorph(@, text)
    m.addItem "Ok"
    m.isDraggable = true
    m.popUpCenteredAtHand @world()

  prompt: (msg, callback, defaultContents, width, floorNum,
    ceilingNum, isRounded) ->
    isNumeric = true  if ceilingNum
    entryField = new StringFieldMorph(
      defaultContents or "",
      width or 100,
      WorldMorph.preferencesAndSettings.prompterFontSize,
      WorldMorph.preferencesAndSettings.prompterFontName,
      false,
      false,
      isNumeric)
    menu = new MenuMorph(@, msg or "", entryField)
    menu.items.push entryField
    if ceilingNum or WorldMorph.preferencesAndSettings.useSliderForInput
      slider = new SliderMorph(
        floorNum or 0,
        ceilingNum,
        parseFloat(defaultContents),
        Math.floor((ceilingNum - floorNum) / 4),
        "horizontal")
      slider.alpha = 1
      slider.color = new Color(225, 225, 225)
      slider.button.color = menu.borderColor
      slider.button.highlightColor = slider.button.color.copy()
      slider.button.highlightColor.b += 100
      slider.button.pressColor = slider.button.color.copy()
      slider.button.pressColor.b += 150
      slider.setHeight WorldMorph.preferencesAndSettings.prompterSliderSize
      if isRounded
        slider.action = (num) ->
          entryField.changed()
          entryField.text.text = Math.round(num).toString()
          entryField.text.updateRendering()
          entryField.text.changed()
          entryField.text.edit()
      else
        slider.action = (num) ->
          entryField.changed()
          entryField.text.text = num.toString()
          entryField.text.updateRendering()
          entryField.text.changed()
      menu.items.push slider
    menu.addLine 2
    menu.addItem "Ok", callback
    #
    menu.addItem "Cancel", ->
      null
    #
    menu.isDraggable = true
    menu.popUpAtHand()
    entryField.text.edit()
  
  pickColor: (msg, callback, defaultContents) ->
    colorPicker = new ColorPickerMorph(defaultContents)
    menu = new MenuMorph(@, msg or "", colorPicker)
    menu.items.push colorPicker
    menu.addLine 2
    menu.addItem "Ok", callback
    #
    menu.addItem "Cancel", ->
      null
    #
    menu.isDraggable = true
    menu.popUpAtHand()

  inspect: (anotherObject) ->
    inspectee = @
    inspectee = anotherObject  if anotherObject
    @spawnInspector inspectee

  spawnInspector: (inspectee) ->
    inspector = new InspectorMorph(inspectee)
    world = (if @world instanceof Function then @world() else (@root() or @world))
    inspector.setPosition world.hand.position()
    inspector.keepWithin world
    world.add inspector
    inspector.changed()
    
  
  # Morph menus ////////////////////////////////////////////////////////////////
  
  contextMenu: ->
    # Spacial multiplexing
    # (search "multiplexing" for the other parts of
    # code where this matters)
    # There are two interpretations of what this
    # list should be:
    #   1) all morphs "pierced through" by the pointer
    #   2) all morphs parents of the topmost morph under the pointer
    # 2 is what is used in Cuis
    
    # commented-out addendum for the implementation of 1):
    #show the normal menu in case there is text selected,
    #otherwise show the spacial multiplexing list
    #if !@world().caret
    #  if @world().hand.allMorphsAtPointer().length > 2
    #    return @hierarchyMenu()
    if @customContextMenu
      return @customContextMenu()
    world = (if @world instanceof Function then @world() else (@root() or @world))
    if world and world.isDevMode
      if @parent is world
        return @developersMenu()
      return @hierarchyMenu()
    @userMenu() or (@parent and @parent.userMenu())
  
  # When user right-clicks on a morph that is a child of other morphs,
  # then it's ambiguous which of the morphs she wants to operate on.
  # An example is right-clicking on a SpeechBubbleMorph: did she
  # mean to operate on the BubbleMorph or did she mean to operate on
  # the TextMorph contained in it?
  # This menu lets her disambiguate.
  hierarchyMenu: ->
    # Spacial multiplexing
    # (search "multiplexing" for the other parts of
    # code where this matters)
    # There are two interpretations of what this
    # list should be:
    #   1) all morphs "pierced through" by the pointer
    #   2) all morphs parents of the topmost morph under the pointer
    # 2 is what is used in Cuis
    # commented-out addendum for the implementation of 1):
    # parents = @world().hand.allMorphsAtPointer().reverse()
    parents = @allParentsTopToBottom()
    world = (if @world instanceof Function then @world() else (@root() or @world))
    menu = new MenuMorph(@, null)
    # show an entry for each of the morphs in the hierarchy.
    # each entry will open the developer menu for each morph.
    parents.forEach (each) ->
      if each.developersMenu and (each isnt world)
        textLabelForMorph = each.toString().slice(0, 50)
        menu.addItem textLabelForMorph, ->
          each.developersMenu().popUpAtHand()
    #  
    menu
  
  developersMenu: ->
    # 'name' is not an official property of a function, hence:
    world = (if @world instanceof Function then @world() else (@root() or @world))
    userMenu = @userMenu() or (@parent and @parent.userMenu())
    menu = new MenuMorph(
      @,
      @constructor.name or @constructor.toString().split(" ")[1].split("(")[0])
    if userMenu
      menu.addItem "user features...", ->
        userMenu.popUpAtHand()
      #
      menu.addLine()
    menu.addItem "color...", (->
      @pickColor menu.title + "\ncolor:", @setColor, @color
    ), "choose another color \nfor this morph"

    menu.addItem "transparency...", (->
      @prompt menu.title + "\nalpha\nvalue:",
        @setAlphaScaled, (@alpha * 100).toString(),
        null,
        1,
        100,
        true
    ), "set this morph's\nalpha value"
    menu.addItem "resize...", (->@resize()), "show a handle\nwhich can be dragged\nto change this morph's" + " extent"
    menu.addLine()
    menu.addItem "duplicate", (->
      aFullCopy = @fullCopy()
      aFullCopy.pickUp()
    ), "make a copy\nand pick it up"
    menu.addItem "pick up", (->@pickUp()), "disattach and put \ninto the hand"
    menu.addItem "attach...", (->@attach()), "stick this morph\nto another one"
    menu.addItem "move", (->@move()), "show a handle\nwhich can be dragged\nto move this morph"
    menu.addItem "inspect", (->@inspect()), "open a window\non all properties"

    # A) normally, just take a picture of this morph
    # and open it in a new tab.
    # B) If a test is being recorded, then the behaviour
    # is slightly different: a system test command is
    # triggered to take a screenshot of this particular
    # morph.
    # C) If a test is being played, then the screenshot of
    # the particular morph is put in a special place
    # in the test player. The command recorded at B) is
    # going to replay but *waiting* for that screenshot
    # first.
    takePic = =>
      if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.RECORDING
        # While recording a test, just trigger for
        # the takeScreenshot command to be recorded. 
        window.world.systemTestsRecorderAndPlayer.takeScreenshot(@)
      else if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.PLAYING
        # While playing a test, this command puts the
        # screenshot of this morph in a special
        # variable of the system test runner.
        # The test runner will wait for this variable
        # to contain the morph screenshot before
        # doing the comparison as per command recorded
        # in the case above.
        window.world.systemTestsRecorderAndPlayer.imageDataOfAParticularMorph = @fullImageData()
      else
        # no system tests recording/playing ongoing,
        # just open new tab with image of morph.
        window.open @fullImageData()
    menu.addItem "take pic", takePic, "open a new window\nwith a picture of this morph"

    menu.addLine()
    if @isDraggable
      menu.addItem "lock", (->@toggleIsDraggable()), "make this morph\nunmovable"
    else
      menu.addItem "unlock", (->@toggleIsDraggable()), "make this morph\nmovable"
    menu.addItem "hide", (->@minimise())
    menu.addItem "delete", (->@destroy())
    menu
  
  userMenu: ->
    null
  
  
  # Morph menu actions
  calculateAlphaScaled: (alpha) ->
    if typeof alpha is "number"
      unscaled = alpha / 100
      return Math.min(Math.max(unscaled, 0.1), 1)
    else
      newAlpha = parseFloat(alpha)
      unless isNaN(newAlpha)
        unscaled = newAlpha / 100
        return Math.min(Math.max(unscaled, 0.1), 1)

  setAlphaScaled: (alphaOrMorphGivingAlpha) ->
    if alphaOrMorphGivingAlpha.getValue?
      alpha = alphaOrMorphGivingAlpha.getValue()
    else
      alpha = alphaOrMorphGivingAlpha
    if alpha
      @alpha = @calculateAlphaScaled(alpha)
      @changed()
  
  attach: ->
    # get rid of any previous temporary
    # active menu because it's meant to be
    # out of view anyways, otherwise we show
    # its overlapping morphs in the options
    # which is most probably not wanted.
    if world.activeMenu
      world.activeMenu = world.activeMenu.destroy()
    choices = world.plausibleTargetAndDestinationMorphs(@)

    # my direct parent might be in the
    # options which is silly, leave that one out
    choicesExcludingParent = []
    choices.forEach (each) =>
      if each != @parent
        choicesExcludingParent.push each

    if choicesExcludingParent.length > 0
      menu = new MenuMorph(@, "choose new parent:")
      choicesExcludingParent.forEach (each) =>
        menu.addItem each.toString().slice(0, 50), =>
          # this is what happens when "each" is
          # selected: we attach the selected morph
          each.add @
          if each instanceof FrameMorph
            each.adjustBounds()
          else
            # you expect Morphs attached
            # inside a FrameMorph
            # to be draggable out of it
            # (as opposed to the content of a ScrollFrameMorph)
            @isDraggable = false
    else
      # the ideal would be to not show the
      # "attach" menu entry at all but for the
      # time being it's quite costly to
      # find the eligible morphs to attach
      # to, so for now let's just calculate
      # this list if the user invokes the
      # command, and if there are no good
      # morphs then show some kind of message.
      menu = new MenuMorph(@, "no morphs to attach to")
    menu.popUpAtHand()
  
  toggleIsDraggable: ->
    # for context menu demo purposes
    @isDraggable = not @isDraggable
  
  colorSetters: ->
    # for context menu demo purposes
    ["color"]
  
  numericalSetters: ->
    # for context menu demo purposes
    ["setLeft", "setTop", "setWidth", "setHeight", "setAlphaScaled"]
  
  
  # Morph entry field tabbing //////////////////////////////////////////////
  
  allEntryFields: ->
    @collectAllChildrenBottomToTopSuchThat (each) ->
      each.isEditable && (each instanceof StringMorph || each instanceof TextMorph);
  
  
  nextEntryField: (current) ->
    fields = @allEntryFields()
    idx = fields.indexOf(current)
    if idx isnt -1
      if fields.length > (idx + 1)
        return fields[idx + 1]
    return fields[0]
  
  previousEntryField: (current) ->
    fields = @allEntryFields()
    idx = fields.indexOf(current)
    if idx isnt -1
      if idx > 0
        return fields[idx - 1]
      return fields[fields.length - 1]
    return fields[0]
  
  tab: (editField) ->
    #
    #	the <tab> key was pressed in one of my edit fields.
    #	invoke my "nextTab()" function if it exists, else
    #	propagate it up my owner chain.
    #
    if @nextTab
      @nextTab editField
    else @parent.tab editField  if @parent
  
  backTab: (editField) ->
    #
    #	the <back tab> key was pressed in one of my edit fields.
    #	invoke my "previousTab()" function if it exists, else
    #	propagate it up my owner chain.
    #
    if @previousTab
      @previousTab editField
    else @parent.backTab editField  if @parent
  
  
  #
  #	the following are examples of what the navigation methods should
  #	look like. Insert these at the World level for fallback, and at lower
  #	levels in the Morphic tree (e.g. dialog boxes) for a more fine-grained
  #	control over the tabbing cycle.
  #
  #Morph.prototype.nextTab = function (editField) {
  #	var	next = this.nextEntryField(editField);
  #	editField.clearSelection();
  #	next.selectAll();
  #	next.edit();
  #};
  #
  #Morph.prototype.previousTab = function (editField) {
  #	var	prev = this.previousEntryField(editField);
  #	editField.clearSelection();
  #	prev.selectAll();
  #	prev.edit();
  #};
  #
  #
  
  # Morph events:
  escalateEvent: (functionName, arg) ->
    handler = @parent
    if handler?
      handler = handler.parent  while not handler[functionName] and handler.parent?
      handler[functionName] arg  if handler[functionName]
  
  
  # Morph eval. Used by the Inspector and the TextMorph.
  evaluateString: (code) ->
    try
      result = eval(code)
      @updateRendering()
      @changed()
    catch err
      @inform err
    result
  
  
  # Morph collision detection - not used anywhere at the moment ////////////////////////
  
  isTouching: (otherMorph) ->
    oImg = @overlappingImage(otherMorph)
    data = oImg.getContext("2d").getImageData(1, 1, oImg.width, oImg.height).data
    detect(data, (each) ->
      each isnt 0
    ) isnt null
  
  overlappingImage: (otherMorph) ->
    fb = @boundsIncludingChildren()
    otherFb = otherMorph.boundsIncludingChildren()
    oRect = fb.intersect(otherFb)
    oImg = newCanvas(oRect.extent().scaleBy pixelRatio)
    ctx = oImg.getContext("2d")
    ctx.scale pixelRatio, pixelRatio
    if oRect.width() < 1 or oRect.height() < 1
      return newCanvas((new Point(1, 1)).scaleBy pixelRatio)
    ctx.drawImage @fullImage(),
      Math.round(oRect.origin.x - fb.origin.x),
      Math.round(oRect.origin.y - fb.origin.y)
    ctx.globalCompositeOperation = "source-in"
    ctx.drawImage otherMorph.fullImage(),
      Math.round(otherFb.origin.x - oRect.origin.x),
      Math.round(otherFb.origin.y - oRect.origin.y)
    oImg
  '''

# BlinkerMorph ////////////////////////////////////////////////////////

# can be used for text caret

class BlinkerMorph extends Morph
  constructor: (@fps = 2) ->
    super()
    @color = new Color(0, 0, 0)
  
  # BlinkerMorph stepping:
  step: ->
    # if we are recording or playing a test
    # then there is a flag we need to check that allows
    # the world to control all the animations.
    # This is so there is a consistent check
    # when taking/comparing
    # screenshots.
    # So we check here that flag, and make the
    # caret is always going to be visible.
    if SystemTestsRecorderAndPlayer.animationsPacingControl and
     SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE
      return
 
    # in all other cases just
    # do like usual, i.e. toggle
    # visibility at the fps
    # specified in the constructor.
    @toggleVisibility()

  @coffeeScriptSourceOfThisClass: '''
# BlinkerMorph ////////////////////////////////////////////////////////

# can be used for text caret

class BlinkerMorph extends Morph
  constructor: (@fps = 2) ->
    super()
    @color = new Color(0, 0, 0)
  
  # BlinkerMorph stepping:
  step: ->
    # if we are recording or playing a test
    # then there is a flag we need to check that allows
    # the world to control all the animations.
    # This is so there is a consistent check
    # when taking/comparing
    # screenshots.
    # So we check here that flag, and make the
    # caret is always going to be visible.
    if SystemTestsRecorderAndPlayer.animationsPacingControl and
     SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE
      return
 
    # in all other cases just
    # do like usual, i.e. toggle
    # visibility at the fps
    # specified in the constructor.
    @toggleVisibility()
  '''

# BouncerMorph ////////////////////////////////////////////////////////
# fishy constructor
# I am a Demo of a stepping custom Morph
# Bounces vertically or horizontally within the parent

class BouncerMorph extends Morph

  isStopped: false
  type: null
  direction: null
  speed: null

  constructor: (@type = "vertical", @speed = 1) ->
    super()
    @fps = 50
    # additional properties:
    if @type is "vertical"
      @direction = "down"
    else
      @direction = "right"

    # @updateRendering() not needed, probably
    # because it's repainted in the
    # next frame since it's an animation?
    #@updateRendering()

  resetPosition: ->
    if @type is "vertical"
      @direction = "down"
    else
      @direction = "right"
    @setPosition new Point(@parent.position().x, @parent.position().y)
  
  
  # BouncerMorph moving.
  # We need the silent option because
  # we might move the bouncer many times
  # consecutively in the case we tie
  # the animation to the test step.
  # The silent option avoids too many
  # broken rectangles being pushed
  # so it makes the whole thing smooth
  # even with many movements at once.
  moveUp: (silently) ->
    if silently
      @silentMoveBy new Point(0, -@speed)
    else
      @moveBy new Point(0, -@speed)
  
  moveDown: (silently) ->
    if silently
      @silentMoveBy new Point(0, @speed)
    else
      @moveBy new Point(0, @speed)
  
  moveRight: (silently) ->
    if silently
      @silentMoveBy new Point(@speed, 0)
    else
      @moveBy new Point(@speed, 0)
  
  moveLeft: (silently) ->
    if silently
      @silentMoveBy new Point(-@speed, 0)
    else
      @moveBy new Point(-@speed, 0)

  moveAccordingToBounce: (silently) ->
    if @type is "vertical"
      if @direction is "down"
        @moveDown(silently)
      else
        @moveUp(silently)
      @direction = "down"  if @boundsIncludingChildren().top() < @parent.top() and @direction is "up"
      @direction = "up"  if @boundsIncludingChildren().bottom() > @parent.bottom() and @direction is "down"
    else if @type is "horizontal"
      if @direction is "right"
        @moveRight(silently)
      else
        @moveLeft(silently)
      @direction = "right"  if @boundsIncludingChildren().left() < @parent.left() and @direction is "left"
      @direction = "left"  if @boundsIncludingChildren().right() > @parent.right() and @direction is "right"
  
  
  # BouncerMorph stepping:
  step: ->
    unless @isStopped
      # if we are recording or playing a test
      # then there is a flag we need to check that allows
      # the world to control all the animations.
      # This is so there is a consistent check
      # when taking/comparing
      # screenshots.
      # So we check here that flag, and make the
      # animation is exactly controlled
      # by the test step count only.
      #console.log "SystemTestsRecorderAndPlayer.animationsPacingControl: " + SystemTestsRecorderAndPlayer.animationsPacingControl
      #console.log "state: " + SystemTestsRecorderAndPlayer.state
      if SystemTestsRecorderAndPlayer.animationsPacingControl
        if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.RECORDING
          @resetPosition()
          for i in [0... window.world.systemTestsRecorderAndPlayer.testCommandsSequence.length]
            @moveAccordingToBounce(true)
          @parent.changed()
          return
        if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.PLAYING
          @resetPosition()
          for i in [0... window.world.systemTestsRecorderAndPlayer.indexOfTestCommandBeingPlayedFromSequence]
            @moveAccordingToBounce(true)
          @parent.changed()
          return

      @moveAccordingToBounce(false)

  @coffeeScriptSourceOfThisClass: '''
# BouncerMorph ////////////////////////////////////////////////////////
# fishy constructor
# I am a Demo of a stepping custom Morph
# Bounces vertically or horizontally within the parent

class BouncerMorph extends Morph

  isStopped: false
  type: null
  direction: null
  speed: null

  constructor: (@type = "vertical", @speed = 1) ->
    super()
    @fps = 50
    # additional properties:
    if @type is "vertical"
      @direction = "down"
    else
      @direction = "right"

    # @updateRendering() not needed, probably
    # because it's repainted in the
    # next frame since it's an animation?
    #@updateRendering()

  resetPosition: ->
    if @type is "vertical"
      @direction = "down"
    else
      @direction = "right"
    @setPosition new Point(@parent.position().x, @parent.position().y)
  
  
  # BouncerMorph moving.
  # We need the silent option because
  # we might move the bouncer many times
  # consecutively in the case we tie
  # the animation to the test step.
  # The silent option avoids too many
  # broken rectangles being pushed
  # so it makes the whole thing smooth
  # even with many movements at once.
  moveUp: (silently) ->
    if silently
      @silentMoveBy new Point(0, -@speed)
    else
      @moveBy new Point(0, -@speed)
  
  moveDown: (silently) ->
    if silently
      @silentMoveBy new Point(0, @speed)
    else
      @moveBy new Point(0, @speed)
  
  moveRight: (silently) ->
    if silently
      @silentMoveBy new Point(@speed, 0)
    else
      @moveBy new Point(@speed, 0)
  
  moveLeft: (silently) ->
    if silently
      @silentMoveBy new Point(-@speed, 0)
    else
      @moveBy new Point(-@speed, 0)

  moveAccordingToBounce: (silently) ->
    if @type is "vertical"
      if @direction is "down"
        @moveDown(silently)
      else
        @moveUp(silently)
      @direction = "down"  if @boundsIncludingChildren().top() < @parent.top() and @direction is "up"
      @direction = "up"  if @boundsIncludingChildren().bottom() > @parent.bottom() and @direction is "down"
    else if @type is "horizontal"
      if @direction is "right"
        @moveRight(silently)
      else
        @moveLeft(silently)
      @direction = "right"  if @boundsIncludingChildren().left() < @parent.left() and @direction is "left"
      @direction = "left"  if @boundsIncludingChildren().right() > @parent.right() and @direction is "right"
  
  
  # BouncerMorph stepping:
  step: ->
    unless @isStopped
      # if we are recording or playing a test
      # then there is a flag we need to check that allows
      # the world to control all the animations.
      # This is so there is a consistent check
      # when taking/comparing
      # screenshots.
      # So we check here that flag, and make the
      # animation is exactly controlled
      # by the test step count only.
      #console.log "SystemTestsRecorderAndPlayer.animationsPacingControl: " + SystemTestsRecorderAndPlayer.animationsPacingControl
      #console.log "state: " + SystemTestsRecorderAndPlayer.state
      if SystemTestsRecorderAndPlayer.animationsPacingControl
        if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.RECORDING
          @resetPosition()
          for i in [0... window.world.systemTestsRecorderAndPlayer.testCommandsSequence.length]
            @moveAccordingToBounce(true)
          @parent.changed()
          return
        if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.PLAYING
          @resetPosition()
          for i in [0... window.world.systemTestsRecorderAndPlayer.indexOfTestCommandBeingPlayedFromSequence]
            @moveAccordingToBounce(true)
          @parent.changed()
          return

      @moveAccordingToBounce(false)
  '''

# BoxMorph ////////////////////////////////////////////////////////////

# I can have an optionally rounded border

class BoxMorph extends Morph

  edge: null
  border: null
  borderColor: null

  constructor: (@edge = 4, border, borderColor) ->
    @border = border or ((if (border is 0) then 0 else 2))
    @borderColor = borderColor or new Color()
    super()

  
  # BoxMorph drawing:
  updateRendering: ->
    @image = newCanvas(@extent().scaleBy pixelRatio)
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    if (@edge is 0) and (@border is 0)
      super()
      return null
    context.fillStyle = @color.toString()
    context.beginPath()
    @outlinePath context, Math.max(@edge - @border, 0), @border
    context.closePath()
    context.fill()
    #if @border > 0
    #  context.lineWidth = @border
    #  context.strokeStyle = @borderColor.toString()
    #  context.beginPath()
    #  @outlinePath context, @edge, @border / 2
    #  context.closePath()
    #  context.stroke()
  
  outlinePath: (context, radius, inset) ->
    offset = radius + inset
    w = @width()
    h = @height()
    # top left:
    context.arc offset, offset, radius, radians(-180), radians(-90), false
    # top right:
    context.arc w - offset, offset, radius, radians(-90), radians(-0), false
    # bottom right:
    context.arc w - offset, h - offset, radius, radians(0), radians(90), false
    # bottom left:
    context.arc offset, h - offset, radius, radians(90), radians(180), false
  
  
  # BoxMorph menus:
  developersMenu: ->
    menu = super()
    menu.addLine()

    menu.addItem "border width...", (->
      @prompt menu.title + "\nborder\nwidth:",
        @setBorderWidth,
        @border.toString(),
        null,
        0,
        100,
        true
    ), "set the border's\nline size"
    menu.addItem "border color...", (->
      @pickColor menu.title + "\nborder color:", @setBorderColor, @borderColor
    ), "set the border's\nline color"
    menu.addItem "corner size...", (->
      @prompt menu.title + "\ncorner\nsize:",
        @setCornerSize,
        @edge.toString(),
        null,
        0,
        100,
        true
    ), "set the corner's\nradius"
    menu
  
  setBorderWidth: (sizeOrMorphGivingSize) ->
    if sizeOrMorphGivingSize.getValue?
      size = sizeOrMorphGivingSize.getValue()
    else
      size = sizeOrMorphGivingSize

    # for context menu demo purposes
    if typeof size is "number"
      @border = Math.max(size, 0)
    else
      newSize = parseFloat(size)
      @border = Math.max(newSize, 0)  unless isNaN(newSize)
    @updateRendering()
    @changed()
  

  setBorderColor: (aColorOrAMorphGivingAColor) ->
    if aColorOrAMorphGivingAColor.getColor?
      aColor = aColorOrAMorphGivingAColor.getColor()
    else
      aColor = aColorOrAMorphGivingAColor

    if aColor
      @borderColor = aColor
      @updateRendering()
      @changed()
  
  setCornerSize: (sizeOrMorphGivingSize) ->
    if sizeOrMorphGivingSize.getValue?
      size = sizeOrMorphGivingSize.getValue()
    else
      size = sizeOrMorphGivingSize

    # for context menu demo purposes
    if typeof size is "number"
      @edge = Math.max(size, 0)
    else
      newSize = parseFloat(size)
      @edge = Math.max(newSize, 0)  unless isNaN(newSize)
    @updateRendering()
    @changed()
  
  colorSetters: ->
    # for context menu demo purposes
    ["color", "borderColor"]
  
  numericalSetters: ->
    # for context menu demo purposes
    list = super()
    list.push "setBorderWidth", "setCornerSize"
    list

  @coffeeScriptSourceOfThisClass: '''
# BoxMorph ////////////////////////////////////////////////////////////

# I can have an optionally rounded border

class BoxMorph extends Morph

  edge: null
  border: null
  borderColor: null

  constructor: (@edge = 4, border, borderColor) ->
    @border = border or ((if (border is 0) then 0 else 2))
    @borderColor = borderColor or new Color()
    super()

  
  # BoxMorph drawing:
  updateRendering: ->
    @image = newCanvas(@extent().scaleBy pixelRatio)
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    if (@edge is 0) and (@border is 0)
      super()
      return null
    context.fillStyle = @color.toString()
    context.beginPath()
    @outlinePath context, Math.max(@edge - @border, 0), @border
    context.closePath()
    context.fill()
    #if @border > 0
    #  context.lineWidth = @border
    #  context.strokeStyle = @borderColor.toString()
    #  context.beginPath()
    #  @outlinePath context, @edge, @border / 2
    #  context.closePath()
    #  context.stroke()
  
  outlinePath: (context, radius, inset) ->
    offset = radius + inset
    w = @width()
    h = @height()
    # top left:
    context.arc offset, offset, radius, radians(-180), radians(-90), false
    # top right:
    context.arc w - offset, offset, radius, radians(-90), radians(-0), false
    # bottom right:
    context.arc w - offset, h - offset, radius, radians(0), radians(90), false
    # bottom left:
    context.arc offset, h - offset, radius, radians(90), radians(180), false
  
  
  # BoxMorph menus:
  developersMenu: ->
    menu = super()
    menu.addLine()

    menu.addItem "border width...", (->
      @prompt menu.title + "\nborder\nwidth:",
        @setBorderWidth,
        @border.toString(),
        null,
        0,
        100,
        true
    ), "set the border's\nline size"
    menu.addItem "border color...", (->
      @pickColor menu.title + "\nborder color:", @setBorderColor, @borderColor
    ), "set the border's\nline color"
    menu.addItem "corner size...", (->
      @prompt menu.title + "\ncorner\nsize:",
        @setCornerSize,
        @edge.toString(),
        null,
        0,
        100,
        true
    ), "set the corner's\nradius"
    menu
  
  setBorderWidth: (sizeOrMorphGivingSize) ->
    if sizeOrMorphGivingSize.getValue?
      size = sizeOrMorphGivingSize.getValue()
    else
      size = sizeOrMorphGivingSize

    # for context menu demo purposes
    if typeof size is "number"
      @border = Math.max(size, 0)
    else
      newSize = parseFloat(size)
      @border = Math.max(newSize, 0)  unless isNaN(newSize)
    @updateRendering()
    @changed()
  

  setBorderColor: (aColorOrAMorphGivingAColor) ->
    if aColorOrAMorphGivingAColor.getColor?
      aColor = aColorOrAMorphGivingAColor.getColor()
    else
      aColor = aColorOrAMorphGivingAColor

    if aColor
      @borderColor = aColor
      @updateRendering()
      @changed()
  
  setCornerSize: (sizeOrMorphGivingSize) ->
    if sizeOrMorphGivingSize.getValue?
      size = sizeOrMorphGivingSize.getValue()
    else
      size = sizeOrMorphGivingSize

    # for context menu demo purposes
    if typeof size is "number"
      @edge = Math.max(size, 0)
    else
      newSize = parseFloat(size)
      @edge = Math.max(newSize, 0)  unless isNaN(newSize)
    @updateRendering()
    @changed()
  
  colorSetters: ->
    # for context menu demo purposes
    ["color", "borderColor"]
  
  numericalSetters: ->
    # for context menu demo purposes
    list = super()
    list.push "setBorderWidth", "setCornerSize"
    list
  '''

# CaretMorph /////////////////////////////////////////////////////////

# I mark where the caret is in a String/Text while editing

class CaretMorph extends BlinkerMorph

  keyDownEventUsed: false
  target: null
  originalContents: null
  slot: null
  viewPadding: 1

  constructor: (@target) ->
    # additional properties:
    @originalContents = @target.text
    @originalAlignment = @target.alignment
    @slot = @target.text.length
    super()
    ls = fontHeight(@target.fontSize)
    @setExtent new Point(Math.max(Math.floor(ls / 20), 1), ls)
    if (@target instanceof TextMorph && (@target.alignment != 'left'))
      @target.setAlignmentToLeft()
    @gotoSlot @slot
  
  updateRendering: ->
    super()
    # it'd be cool to do this only
    # once but we don't want to paint stuff in
    # the constructor...
    context = @image.getContext("2d")
    context.font = @target.font()

  # CaretMorph event processing:
  processKeyPress: (charCode, symbol, shiftKey, ctrlKey, altKey, metaKey) ->
    # @inspectKeyEvent event
    if @keyDownEventUsed
      @keyDownEventUsed = false
      return null
    if ctrlKey
      @ctrl charCode
    # in Chrome/OSX cmd-a and cmd-z
    # don't trigger a keypress so this
    # function invocation here does
    # nothing.
    else if metaKey
      @cmd charCode
    else
      @insert symbol, shiftKey
    # notify target's parent of key event
    @target.escalateEvent "reactToKeystroke", charCode, symbol, shiftKey, ctrlKey, altKey, metaKey
  
  processKeyDown: (scanCode, shiftKey, ctrlKey, altKey, metaKey) ->
    # this.inspectKeyEvent(event);
    @keyDownEventUsed = false
    if ctrlKey
      @ctrl scanCode
      # notify target's parent of key event
      @target.escalateEvent "reactToKeystroke", scanCode, null, shiftKey, ctrlKey, altKey, metaKey
      return
    else if metaKey
      @cmd scanCode
      # notify target's parent of key event
      @target.escalateEvent "reactToKeystroke", scanCode, null, shiftKey, ctrlKey, altKey, metaKey
      return
    switch scanCode
      when 37
        @goLeft(shiftKey)
        @keyDownEventUsed = true
      when 39
        @goRight(shiftKey)
        @keyDownEventUsed = true
      when 38
        @goUp(shiftKey)
        @keyDownEventUsed = true
      when 40
        @goDown(shiftKey)
        @keyDownEventUsed = true
      when 36
        @goHome(shiftKey)
        @keyDownEventUsed = true
      when 35
        @goEnd(shiftKey)
        @keyDownEventUsed = true
      when 46
        @deleteRight()
        @keyDownEventUsed = true
      when 8
        @deleteLeft()
        @keyDownEventUsed = true
      when 13
        # we can't check the class using instanceOf
        # because TextMorphs are instances of StringMorphs
        # but they want the enter to insert a carriage return.
        if @target.constructor.name == "StringMorph"
          @accept()
        else
          @insert "\n"
        @keyDownEventUsed = true
      when 27
        @cancel()
        @keyDownEventUsed = true
      else
    # this.inspectKeyEvent(event);
    # notify target's parent of key event
    @target.escalateEvent "reactToKeystroke", scanCode, null, shiftKey, ctrlKey, altKey, metaKey
  
  
  # CaretMorph navigation - simple version
  #gotoSlot: (newSlot) ->
  #  @setPosition @target.slotCoordinates(newSlot)
  #  @slot = Math.max(newSlot, 0)

  gotoSlot: (slot) ->
    # check that slot is within the allowed boundaries of
    # of zero and text length.
    length = @target.text.length
    @slot = (if slot < 0 then 0 else (if slot > length then length else slot))

    pos = @target.slotCoordinates(@slot)
    if @parent and @target.isScrollable
      right = @parent.right() - @viewPadding
      left = @parent.left() + @viewPadding
      if pos.x > right
        @target.setLeft @target.left() + right - pos.x
        pos.x = right
      if pos.x < left
        left = Math.min(@parent.left(), left)
        @target.setLeft @target.left() + left - pos.x
        pos.x = left
      if @target.right() < right and right - @target.width() < left
        pos.x += right - @target.right()
        @target.setRight right
    @show()
    @setPosition pos

    if @parent and @parent.parent instanceof ScrollFrameMorph and @target.isScrollable
      @parent.parent.scrollCaretIntoView @
  
  goLeft: (shift) ->
    @updateSelection shift
    @gotoSlot @slot - 1
    @updateSelection shift
  
  goRight: (shift, howMany) ->
    @updateSelection shift
    @gotoSlot @slot + (howMany || 1)
    @updateSelection shift
  
  goUp: (shift) ->
    @updateSelection shift
    @gotoSlot @target.upFrom(@slot)
    @updateSelection shift
  
  goDown: (shift) ->
    @updateSelection shift
    @gotoSlot @target.downFrom(@slot)
    @updateSelection shift
  
  goHome: (shift) ->
    @updateSelection shift
    @gotoSlot @target.startOfLine(@slot)
    @updateSelection shift
  
  goEnd: (shift) ->
    @updateSelection shift
    @gotoSlot @target.endOfLine(@slot)
    @updateSelection shift
  
  gotoPos: (aPoint) ->
    @gotoSlot @target.slotAt(aPoint)
    @show()

  updateSelection: (shift) ->
    if shift
      if (@target.endMark is null) and (@target.startMark is null)
        @target.startMark = @slot
        @target.endMark = @slot
      else if @target.endMark isnt @slot
        @target.endMark = @slot
        @target.updateRendering()
        @target.changed()
    else
      @target.clearSelection()  
  
  # CaretMorph editing.

  # User presses enter on a stringMorph
  accept: ->
    world = @root()
    world.stopEditing()  if world
    @escalateEvent "accept", null
  
  # User presses ESC
  cancel: ->
    world = @root()
    @undo()
    world.stopEditing()  if world
    @escalateEvent 'cancel', null
    
  # User presses CTRL-Z or CMD-Z
  # Note that this is not a real undo,
  # what we are doing here is just reverting
  # all the changes and sort-of-resetting the
  # state of the target.
  undo: ->
    @target.text = @originalContents
    @target.clearSelection()
    
    # in theory these three lines are not
    # needed because clearSelection runs them
    # already, but I'm leaving them here
    # until I understand better this changed
    # vs. updateRendering semantics.
    @target.changed()
    @target.updateRendering()
    @target.changed()

    @gotoSlot 0
  
  insert: (symbol, shiftKey) ->
    if symbol is "\t"
      @target.escalateEvent 'reactToEdit', @target
      if shiftKey
        return @target.backTab(@target);
      return @target.tab(@target)
    if not @target.isNumeric or not isNaN(parseFloat(symbol)) or contains(["-", "."], symbol)
      if @target.selection() isnt ""
        @gotoSlot @target.selectionStartSlot()
        @target.deleteSelection()
      text = @target.text
      text = text.slice(0, @slot) + symbol + text.slice(@slot)
      @target.text = text
      @target.updateRendering()
      @target.changed()
      @goRight false, symbol.length
  
  ctrl: (scanCodeOrCharCode) ->
    # ctrl-a apparently can come from either
    # keypress or keydown
    # 64 is for keydown
    # 97 is for keypress
    # in Chrome on OSX there is no keypress
    if (scanCodeOrCharCode is 97) or (scanCodeOrCharCode is 65)
      @target.selectAll()
    # ctrl-z arrives both via keypress and
    # keydown but 90 here matches the keydown only
    else if scanCodeOrCharCode is 90
      @undo()
    # unclear which keyboard needs ctrl
    # to be pressed to give a keypressed
    # event for {}[]@
    # but this is what this catches
    else if scanCodeOrCharCode is 123
      @insert "{"
    else if scanCodeOrCharCode is 125
      @insert "}"
    else if scanCodeOrCharCode is 91
      @insert "["
    else if scanCodeOrCharCode is 93
      @insert "]"
    else if scanCodeOrCharCode is 64
      @insert "@"
  
  # these two arrive only from
  # keypressed, at least in Chrome/OSX
  # 65 and 90 are both scan codes.
  cmd: (scanCode) ->
    # CMD-A
    if scanCode is 65
      @target.selectAll()
    # CMD-Z
    else if scanCode is 90
      @undo()
  
  deleteRight: ->
    if @target.selection() isnt ""
      @gotoSlot @target.selectionStartSlot()
      @target.deleteSelection()
    else
      text = @target.text
      @target.changed()
      text = text.slice(0, @slot) + text.slice(@slot + 1)
      @target.text = text
      @target.updateRendering()
  
  deleteLeft: ->
    if @target.selection()
      @gotoSlot @target.selectionStartSlot()
      return @target.deleteSelection()
    text = @target.text
    @target.changed()
    @target.text = text.substring(0, @slot - 1) + text.substr(@slot)
    @target.updateRendering()
    @goLeft()

  # CaretMorph destroying:
  destroy: ->
    if @target.alignment isnt @originalAlignment
      @target.alignment = @originalAlignment
      @target.updateRendering()
      @target.changed()
    super  
  
  # CaretMorph utilities:
  inspectKeyEvent: (event) ->
    # private
    @inform "Key pressed: " + String.fromCharCode(event.charCode) + "\n------------------------" + "\ncharCode: " + event.charCode + "\nkeyCode: " + event.keyCode + "\naltKey: " + event.altKey + "\nctrlKey: " + event.ctrlKey  + "\ncmdKey: " + event.metaKey

  @coffeeScriptSourceOfThisClass: '''
# CaretMorph /////////////////////////////////////////////////////////

# I mark where the caret is in a String/Text while editing

class CaretMorph extends BlinkerMorph

  keyDownEventUsed: false
  target: null
  originalContents: null
  slot: null
  viewPadding: 1

  constructor: (@target) ->
    # additional properties:
    @originalContents = @target.text
    @originalAlignment = @target.alignment
    @slot = @target.text.length
    super()
    ls = fontHeight(@target.fontSize)
    @setExtent new Point(Math.max(Math.floor(ls / 20), 1), ls)
    if (@target instanceof TextMorph && (@target.alignment != 'left'))
      @target.setAlignmentToLeft()
    @gotoSlot @slot
  
  updateRendering: ->
    super()
    # it'd be cool to do this only
    # once but we don't want to paint stuff in
    # the constructor...
    context = @image.getContext("2d")
    context.font = @target.font()

  # CaretMorph event processing:
  processKeyPress: (charCode, symbol, shiftKey, ctrlKey, altKey, metaKey) ->
    # @inspectKeyEvent event
    if @keyDownEventUsed
      @keyDownEventUsed = false
      return null
    if ctrlKey
      @ctrl charCode
    # in Chrome/OSX cmd-a and cmd-z
    # don't trigger a keypress so this
    # function invocation here does
    # nothing.
    else if metaKey
      @cmd charCode
    else
      @insert symbol, shiftKey
    # notify target's parent of key event
    @target.escalateEvent "reactToKeystroke", charCode, symbol, shiftKey, ctrlKey, altKey, metaKey
  
  processKeyDown: (scanCode, shiftKey, ctrlKey, altKey, metaKey) ->
    # this.inspectKeyEvent(event);
    @keyDownEventUsed = false
    if ctrlKey
      @ctrl scanCode
      # notify target's parent of key event
      @target.escalateEvent "reactToKeystroke", scanCode, null, shiftKey, ctrlKey, altKey, metaKey
      return
    else if metaKey
      @cmd scanCode
      # notify target's parent of key event
      @target.escalateEvent "reactToKeystroke", scanCode, null, shiftKey, ctrlKey, altKey, metaKey
      return
    switch scanCode
      when 37
        @goLeft(shiftKey)
        @keyDownEventUsed = true
      when 39
        @goRight(shiftKey)
        @keyDownEventUsed = true
      when 38
        @goUp(shiftKey)
        @keyDownEventUsed = true
      when 40
        @goDown(shiftKey)
        @keyDownEventUsed = true
      when 36
        @goHome(shiftKey)
        @keyDownEventUsed = true
      when 35
        @goEnd(shiftKey)
        @keyDownEventUsed = true
      when 46
        @deleteRight()
        @keyDownEventUsed = true
      when 8
        @deleteLeft()
        @keyDownEventUsed = true
      when 13
        # we can't check the class using instanceOf
        # because TextMorphs are instances of StringMorphs
        # but they want the enter to insert a carriage return.
        if @target.constructor.name == "StringMorph"
          @accept()
        else
          @insert "\n"
        @keyDownEventUsed = true
      when 27
        @cancel()
        @keyDownEventUsed = true
      else
    # this.inspectKeyEvent(event);
    # notify target's parent of key event
    @target.escalateEvent "reactToKeystroke", scanCode, null, shiftKey, ctrlKey, altKey, metaKey
  
  
  # CaretMorph navigation - simple version
  #gotoSlot: (newSlot) ->
  #  @setPosition @target.slotCoordinates(newSlot)
  #  @slot = Math.max(newSlot, 0)

  gotoSlot: (slot) ->
    # check that slot is within the allowed boundaries of
    # of zero and text length.
    length = @target.text.length
    @slot = (if slot < 0 then 0 else (if slot > length then length else slot))

    pos = @target.slotCoordinates(@slot)
    if @parent and @target.isScrollable
      right = @parent.right() - @viewPadding
      left = @parent.left() + @viewPadding
      if pos.x > right
        @target.setLeft @target.left() + right - pos.x
        pos.x = right
      if pos.x < left
        left = Math.min(@parent.left(), left)
        @target.setLeft @target.left() + left - pos.x
        pos.x = left
      if @target.right() < right and right - @target.width() < left
        pos.x += right - @target.right()
        @target.setRight right
    @show()
    @setPosition pos

    if @parent and @parent.parent instanceof ScrollFrameMorph and @target.isScrollable
      @parent.parent.scrollCaretIntoView @
  
  goLeft: (shift) ->
    @updateSelection shift
    @gotoSlot @slot - 1
    @updateSelection shift
  
  goRight: (shift, howMany) ->
    @updateSelection shift
    @gotoSlot @slot + (howMany || 1)
    @updateSelection shift
  
  goUp: (shift) ->
    @updateSelection shift
    @gotoSlot @target.upFrom(@slot)
    @updateSelection shift
  
  goDown: (shift) ->
    @updateSelection shift
    @gotoSlot @target.downFrom(@slot)
    @updateSelection shift
  
  goHome: (shift) ->
    @updateSelection shift
    @gotoSlot @target.startOfLine(@slot)
    @updateSelection shift
  
  goEnd: (shift) ->
    @updateSelection shift
    @gotoSlot @target.endOfLine(@slot)
    @updateSelection shift
  
  gotoPos: (aPoint) ->
    @gotoSlot @target.slotAt(aPoint)
    @show()

  updateSelection: (shift) ->
    if shift
      if (@target.endMark is null) and (@target.startMark is null)
        @target.startMark = @slot
        @target.endMark = @slot
      else if @target.endMark isnt @slot
        @target.endMark = @slot
        @target.updateRendering()
        @target.changed()
    else
      @target.clearSelection()  
  
  # CaretMorph editing.

  # User presses enter on a stringMorph
  accept: ->
    world = @root()
    world.stopEditing()  if world
    @escalateEvent "accept", null
  
  # User presses ESC
  cancel: ->
    world = @root()
    @undo()
    world.stopEditing()  if world
    @escalateEvent 'cancel', null
    
  # User presses CTRL-Z or CMD-Z
  # Note that this is not a real undo,
  # what we are doing here is just reverting
  # all the changes and sort-of-resetting the
  # state of the target.
  undo: ->
    @target.text = @originalContents
    @target.clearSelection()
    
    # in theory these three lines are not
    # needed because clearSelection runs them
    # already, but I'm leaving them here
    # until I understand better this changed
    # vs. updateRendering semantics.
    @target.changed()
    @target.updateRendering()
    @target.changed()

    @gotoSlot 0
  
  insert: (symbol, shiftKey) ->
    if symbol is "\t"
      @target.escalateEvent 'reactToEdit', @target
      if shiftKey
        return @target.backTab(@target);
      return @target.tab(@target)
    if not @target.isNumeric or not isNaN(parseFloat(symbol)) or contains(["-", "."], symbol)
      if @target.selection() isnt ""
        @gotoSlot @target.selectionStartSlot()
        @target.deleteSelection()
      text = @target.text
      text = text.slice(0, @slot) + symbol + text.slice(@slot)
      @target.text = text
      @target.updateRendering()
      @target.changed()
      @goRight false, symbol.length
  
  ctrl: (scanCodeOrCharCode) ->
    # ctrl-a apparently can come from either
    # keypress or keydown
    # 64 is for keydown
    # 97 is for keypress
    # in Chrome on OSX there is no keypress
    if (scanCodeOrCharCode is 97) or (scanCodeOrCharCode is 65)
      @target.selectAll()
    # ctrl-z arrives both via keypress and
    # keydown but 90 here matches the keydown only
    else if scanCodeOrCharCode is 90
      @undo()
    # unclear which keyboard needs ctrl
    # to be pressed to give a keypressed
    # event for {}[]@
    # but this is what this catches
    else if scanCodeOrCharCode is 123
      @insert "{"
    else if scanCodeOrCharCode is 125
      @insert "}"
    else if scanCodeOrCharCode is 91
      @insert "["
    else if scanCodeOrCharCode is 93
      @insert "]"
    else if scanCodeOrCharCode is 64
      @insert "@"
  
  # these two arrive only from
  # keypressed, at least in Chrome/OSX
  # 65 and 90 are both scan codes.
  cmd: (scanCode) ->
    # CMD-A
    if scanCode is 65
      @target.selectAll()
    # CMD-Z
    else if scanCode is 90
      @undo()
  
  deleteRight: ->
    if @target.selection() isnt ""
      @gotoSlot @target.selectionStartSlot()
      @target.deleteSelection()
    else
      text = @target.text
      @target.changed()
      text = text.slice(0, @slot) + text.slice(@slot + 1)
      @target.text = text
      @target.updateRendering()
  
  deleteLeft: ->
    if @target.selection()
      @gotoSlot @target.selectionStartSlot()
      return @target.deleteSelection()
    text = @target.text
    @target.changed()
    @target.text = text.substring(0, @slot - 1) + text.substr(@slot)
    @target.updateRendering()
    @goLeft()

  # CaretMorph destroying:
  destroy: ->
    if @target.alignment isnt @originalAlignment
      @target.alignment = @originalAlignment
      @target.updateRendering()
      @target.changed()
    super  
  
  # CaretMorph utilities:
  inspectKeyEvent: (event) ->
    # private
    @inform "Key pressed: " + String.fromCharCode(event.charCode) + "\n------------------------" + "\ncharCode: " + event.charCode + "\nkeyCode: " + event.keyCode + "\naltKey: " + event.altKey + "\nctrlKey: " + event.ctrlKey  + "\ncmdKey: " + event.metaKey
  '''

# CircleBoxMorph //////////////////////////////////////////////////////

# I can be used for sliders

class CircleBoxMorph extends Morph

  orientation: null
  autoOrient: true

  constructor: (@orientation = "vertical") ->
    super()
    @setExtent new Point(20, 100)

  
  autoOrientation: ->
    if @height() > @width()
      @orientation = "vertical"
    else
      @orientation = "horizontal"
  
  updateRendering: ->
    @autoOrientation()  if @autoOrient
    @image = newCanvas(@extent().scaleBy pixelRatio)
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    if @orientation is "vertical"
      radius = @width() / 2
      x = @center().x
      center1 = new Point(x, @top() + radius)
      center2 = new Point(x, @bottom() - radius)
      rect = @bounds.origin.add(
        new Point(0, radius)).corner(@bounds.corner.subtract(new Point(0, radius)))
    else
      radius = @height() / 2
      y = @center().y
      center1 = new Point(@left() + radius, y)
      center2 = new Point(@right() - radius, y)
      rect = @bounds.origin.add(
        new Point(radius, 0)).corner(@bounds.corner.subtract(new Point(radius, 0)))
    points = [center1.subtract(@bounds.origin), center2.subtract(@bounds.origin)]
    points.forEach (center) =>
      context.fillStyle = @color.toString()
      context.beginPath()
      context.arc center.x, center.y, radius, 0, 2 * Math.PI, false
      context.closePath()
      context.fill()
    rect = rect.translateBy(@bounds.origin.neg())
    ext = rect.extent()
    if ext.x > 0 and ext.y > 0
      context.fillRect rect.origin.x, rect.origin.y, rect.width(), rect.height()
  
  
  # CircleBoxMorph menu:
  developersMenu: ->
    menu = super()
    menu.addLine()
    # todo Dan Ingalls did show a neat demo where the
    # boxmorph was automatically chanding the orientation
    # when resized, following the main direction.
    if @orientation is "vertical"
      menu.addItem "make horizontal", (->@toggleOrientation()), "toggle the\norientation"
    else
      menu.addItem "make vertical", (->@toggleOrientation()), "toggle the\norientation"
    menu
  
  toggleOrientation: ->
    center = @center()
    @changed()
    if @orientation is "vertical"
      @orientation = "horizontal"
    else
      @orientation = "vertical"
    @silentSetExtent new Point(@height(), @width())
    @setCenter center
    @updateRendering()
    @changed()

  @coffeeScriptSourceOfThisClass: '''
# CircleBoxMorph //////////////////////////////////////////////////////

# I can be used for sliders

class CircleBoxMorph extends Morph

  orientation: null
  autoOrient: true

  constructor: (@orientation = "vertical") ->
    super()
    @setExtent new Point(20, 100)

  
  autoOrientation: ->
    if @height() > @width()
      @orientation = "vertical"
    else
      @orientation = "horizontal"
  
  updateRendering: ->
    @autoOrientation()  if @autoOrient
    @image = newCanvas(@extent().scaleBy pixelRatio)
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    if @orientation is "vertical"
      radius = @width() / 2
      x = @center().x
      center1 = new Point(x, @top() + radius)
      center2 = new Point(x, @bottom() - radius)
      rect = @bounds.origin.add(
        new Point(0, radius)).corner(@bounds.corner.subtract(new Point(0, radius)))
    else
      radius = @height() / 2
      y = @center().y
      center1 = new Point(@left() + radius, y)
      center2 = new Point(@right() - radius, y)
      rect = @bounds.origin.add(
        new Point(radius, 0)).corner(@bounds.corner.subtract(new Point(radius, 0)))
    points = [center1.subtract(@bounds.origin), center2.subtract(@bounds.origin)]
    points.forEach (center) =>
      context.fillStyle = @color.toString()
      context.beginPath()
      context.arc center.x, center.y, radius, 0, 2 * Math.PI, false
      context.closePath()
      context.fill()
    rect = rect.translateBy(@bounds.origin.neg())
    ext = rect.extent()
    if ext.x > 0 and ext.y > 0
      context.fillRect rect.origin.x, rect.origin.y, rect.width(), rect.height()
  
  
  # CircleBoxMorph menu:
  developersMenu: ->
    menu = super()
    menu.addLine()
    # todo Dan Ingalls did show a neat demo where the
    # boxmorph was automatically chanding the orientation
    # when resized, following the main direction.
    if @orientation is "vertical"
      menu.addItem "make horizontal", (->@toggleOrientation()), "toggle the\norientation"
    else
      menu.addItem "make vertical", (->@toggleOrientation()), "toggle the\norientation"
    menu
  
  toggleOrientation: ->
    center = @center()
    @changed()
    if @orientation is "vertical"
      @orientation = "horizontal"
    else
      @orientation = "vertical"
    @silentSetExtent new Point(@height(), @width())
    @setCenter center
    @updateRendering()
    @changed()
  '''

# Colors //////////////////////////////////////////////////////////////

class Color

  # This "colourNamesValues" data
  # structure is only used to create
  # all the CSS color literals, like
  #   Color.red
  # This creation of constants
  # is done in WoldMorph, since
  # it's the first morph to be
  # created.
  # In pure theory we'd like these
  # constants to be created by a piece
  # of code at the end of the file, just
  # after the class definition,
  # unfortunately we can't add it there
  # as the source in this file is
  # appended as a further static variable
  # in this class, so we can't
  # "close" the class by adding code
  # that it's supposed to be outside its
  # definition.
  @colourNamesValues =
    aliceblue:            [0xf0,0xf8,0xff]
    antiquewhite:         [0xfa,0xeb,0xd7]
    aqua:                 [0x00,0xff,0xff]
    aquamarine:           [0x7f,0xff,0xd4]
    azure:                [0xf0,0xff,0xff]
    beige:                [0xf5,0xf5,0xdc]
    bisque:               [0xff,0xe4,0xc4]
    black:                [0x00,0x00,0x00]
    blanchedalmond:       [0xff,0xeb,0xcd]
    blue:                 [0x00,0x00,0xff]
    blueviolet:           [0x8a,0x2b,0xe2]
    brown:                [0xa5,0x2a,0x2a]
    burlywood:            [0xde,0xb8,0x87]
    cadetblue:            [0x5f,0x9e,0xa0]
    chartreuse:           [0x7f,0xff,0x00]
    chocolate:            [0xd2,0x69,0x1e]
    coral:                [0xff,0x7f,0x50]
    cornflowerblue:       [0x64,0x95,0xed]
    cornsilk:             [0xff,0xf8,0xdc]
    crimson:              [0xdc,0x14,0x3c]
    cyan:                 [0x00,0xff,0xff]
    darkblue:             [0x00,0x00,0x8b]
    darkcyan:             [0x00,0x8b,0x8b]
    darkgoldenrod:        [0xb8,0x86,0x0b]
    darkgray:             [0xa9,0xa9,0xa9]
    darkgrey:             [0xa9,0xa9,0xa9]
    darkgreen:            [0x00,0x64,0x00]
    darkkhaki:            [0xbd,0xb7,0x6b]
    darkmagenta:          [0x8b,0x00,0x8b]
    darkolivegreen:       [0x55,0x6b,0x2f]
    darkorange:           [0xff,0x8c,0x00]
    darkorchid:           [0x99,0x32,0xcc]
    darkred:              [0x8b,0x00,0x00]
    darksalmon:           [0xe9,0x96,0x7a]
    darkseagreen:         [0x8f,0xbc,0x8f]
    darkslateblue:        [0x48,0x3d,0x8b]
    darkslategray:        [0x2f,0x4f,0x4f]
    darkslategrey:        [0x2f,0x4f,0x4f]
    darkturquoise:        [0x00,0xce,0xd1]
    darkviolet:           [0x94,0x00,0xd3]
    deeppink:             [0xff,0x14,0x93]
    deepskyblue:          [0x00,0xbf,0xff]
    dimgray:              [0x69,0x69,0x69]
    dimgrey:              [0x69,0x69,0x69]
    dodgerblue:           [0x1e,0x90,0xff]
    firebrick:            [0xb2,0x22,0x22]
    floralwhite:          [0xff,0xfa,0xf0]
    forestgreen:          [0x22,0x8b,0x22]
    fuchsia:              [0xff,0x00,0xff]
    gainsboro:            [0xdc,0xdc,0xdc]
    ghostwhite:           [0xf8,0xf8,0xff]
    gold:                 [0xff,0xd7,0x00]
    goldenrod:            [0xda,0xa5,0x20]
    gray:                 [0x80,0x80,0x80]
    grey:                 [0x80,0x80,0x80]
    green:                [0x00,0x80,0x00]
    greenyellow:          [0xad,0xff,0x2f]
    honeydew:             [0xf0,0xff,0xf0]
    hotpink:              [0xff,0x69,0xb4]
    indianred:            [0xcd,0x5c,0x5c]
    indigo:               [0x4b,0x00,0x82]
    ivory:                [0xff,0xff,0xf0]
    khaki:                [0xf0,0xe6,0x8c]
    lavender:             [0xe6,0xe6,0xfa]
    lavenderblush:        [0xff,0xf0,0xf5]
    lawngreen:            [0x7c,0xfc,0x00]
    lemonchiffon:         [0xff,0xfa,0xcd]
    lightblue:            [0xad,0xd8,0xe6]
    lightcoral:           [0xf0,0x80,0x80]
    lightcyan:            [0xe0,0xff,0xff]
    lightgoldenrodyellow: [0xfa,0xfa,0xd2]
    lightgrey:            [0xd3,0xd3,0xd3]
    lightgray:            [0xd3,0xd3,0xd3]
    lightgreen:           [0x90,0xee,0x90]
    lightpink:            [0xff,0xb6,0xc1]
    lightsalmon:          [0xff,0xa0,0x7a]
    lightseagreen:        [0x20,0xb2,0xaa]
    lightskyblue:         [0x87,0xce,0xfa]
    lightslategray:       [0x77,0x88,0x99]
    lightslategrey:       [0x77,0x88,0x99]
    lightsteelblue:       [0xb0,0xc4,0xde]
    lightyellow:          [0xff,0xff,0xe0]
    lime:                 [0x00,0xff,0x00]
    limegreen:            [0x32,0xcd,0x32]
    linen:                [0xfa,0xf0,0xe6]
    mintcream:            [0xf5,0xff,0xfa]
    mistyrose:            [0xff,0xe4,0xe1]
    moccasin:             [0xff,0xe4,0xb5]
    navajowhite:          [0xff,0xde,0xad]
    navy:                 [0x00,0x00,0x80]
    oldlace:              [0xfd,0xf5,0xe6]
    olive:                [0x80,0x80,0x00]
    olivedrab:            [0x6b,0x8e,0x23]
    orange:               [0xff,0xa5,0x00]
    orangered:            [0xff,0x45,0x00]
    orchid:               [0xda,0x70,0xd6]
    palegoldenrod:        [0xee,0xe8,0xaa]
    palegreen:            [0x98,0xfb,0x98]
    paleturquoise:        [0xaf,0xee,0xee]
    palevioletred:        [0xd8,0x70,0x93]
    papayawhip:           [0xff,0xef,0xd5]
    peachpuff:            [0xff,0xda,0xb9]
    peru:                 [0xcd,0x85,0x3f]
    pink:                 [0xff,0xc0,0xcb]
    plum:                 [0xdd,0xa0,0xdd]
    powderblue:           [0xb0,0xe0,0xe6]
    purple:               [0x80,0x00,0x80]
    red:                  [0xff,0x00,0x00]
    rosybrown:            [0xbc,0x8f,0x8f]
    royalblue:            [0x41,0x69,0xe1]
    saddlebrown:          [0x8b,0x45,0x13]
    salmon:               [0xfa,0x80,0x72]
    sandybrown:           [0xf4,0xa4,0x60]
    seagreen:             [0x2e,0x8b,0x57]
    seashell:             [0xff,0xf5,0xee]
    sienna:               [0xa0,0x52,0x2d]
    silver:               [0xc0,0xc0,0xc0]
    skyblue:              [0x87,0xce,0xeb]
    slateblue:            [0x6a,0x5a,0xcd]
    slategray:            [0x70,0x80,0x90]
    slategrey:            [0x70,0x80,0x90]
    snow:                 [0xff,0xfa,0xfa]
    springgreen:          [0x00,0xff,0x7f]
    steelblue:            [0x46,0x82,0xb4]
    tan:                  [0xd2,0xb4,0x8c]
    teal:                 [0x00,0x80,0x80]
    thistle:              [0xd8,0xbf,0xd8]
    tomato:               [0xff,0x63,0x47]
    turquoise:            [0x40,0xe0,0xd0]
    violet:               [0xee,0x82,0xee]
    wheat:                [0xf5,0xde,0xb3]
    white:                [0xff,0xff,0xff]
    whitesmoke:           [0xf5,0xf5,0xf5]
    yellow:               [0xff,0xff,0x00]
    yellowgreen:          [0x9a,0xcd,0x32]

  a: null
  r: null
  g: null
  b: null

  constructor: (@r = 0, @g = 0, @b = 0, a) ->
    # all values are optional, just (r, g, b) is fine
    @a = a or ((if (a is 0) then 0 else 1))
  
  # Color string representation: e.g. 'rgba(255,165,0,1)'
  toString: ->
    "rgba(" + Math.round(@r) + "," + Math.round(@g) + "," + Math.round(@b) + "," + @a + ")"
  
  # Color copying:
  copy: ->
    new @constructor(@r, @g, @b, @a)
  
  # Color comparison:
  eq: (aColor) ->
    # ==
    aColor and @r is aColor.r and @g is aColor.g and @b is aColor.b
  
  
  # Color conversion (hsv):
  hsv: ->
    # ignore alpha
    rr = @r / 255
    gg = @g / 255
    bb = @b / 255
    max = Math.max(rr, gg, bb)
    min = Math.min(rr, gg, bb)
    h = max
    s = max
    v = max
    d = max - min
    s = (if max is 0 then 0 else d / max)
    if max is min
      h = 0
    else
      switch max
        when rr
          h = (gg - bb) / d + ((if gg < bb then 6 else 0))
        when gg
          h = (bb - rr) / d + 2
        when bb
          h = (rr - gg) / d + 4
      h /= 6
    [h, s, v]
  
  set_hsv: (h, s, v) ->
    # ignore alpha
    # h, s and v are to be within [0, 1]
    i = Math.floor(h * 6)
    f = h * 6 - i
    p = v * (1 - s)
    q = v * (1 - f * s)
    t = v * (1 - (1 - f) * s)
    switch i % 6
      when 0
        @r = v
        @g = t
        @b = p
      when 1
        @r = q
        @g = v
        @b = p
      when 2
        @r = p
        @g = v
        @b = t
      when 3
        @r = p
        @g = q
        @b = v
      when 4
        @r = t
        @g = p
        @b = v
      when 5
        @r = v
        @g = p
        @b = q
    @r *= 255
    @g *= 255
    @b *= 255
  
  
  # Color mixing:
  mixed: (proportion, otherColor) ->
    # answer a copy of this color mixed with another color, ignore alpha
    frac1 = Math.min(Math.max(proportion, 0), 1)
    frac2 = 1 - frac1
    new @constructor(
      @r * frac1 + otherColor.r * frac2,
      @g * frac1 + otherColor.g * frac2,
      @b * frac1 + otherColor.b * frac2)
  
  darker: (percent) ->
    # return an rgb-interpolated darker copy of me, ignore alpha
    fract = 0.8333
    fract = (100 - percent) / 100  if percent
    @mixed fract, new @constructor(0, 0, 0)
  
  lighter: (percent) ->
    # return an rgb-interpolated lighter copy of me, ignore alpha
    fract = 0.8333
    fract = (100 - percent) / 100  if percent
    @mixed fract, new @constructor(255, 255, 255)
  
  dansDarker: ->
    # return an hsv-interpolated darker copy of me, ignore alpha
    hsv = @hsv()
    result = new @constructor()
    vv = Math.max(hsv[2] - 0.16, 0)
    result.set_hsv hsv[0], hsv[1], vv
    result

  @transparent: ->
    return new @constructor(0,0,0,0)


  @coffeeScriptSourceOfThisClass: '''
# Colors //////////////////////////////////////////////////////////////

class Color

  # This "colourNamesValues" data
  # structure is only used to create
  # all the CSS color literals, like
  #   Color.red
  # This creation of constants
  # is done in WoldMorph, since
  # it's the first morph to be
  # created.
  # In pure theory we'd like these
  # constants to be created by a piece
  # of code at the end of the file, just
  # after the class definition,
  # unfortunately we can't add it there
  # as the source in this file is
  # appended as a further static variable
  # in this class, so we can't
  # "close" the class by adding code
  # that it's supposed to be outside its
  # definition.
  @colourNamesValues =
    aliceblue:            [0xf0,0xf8,0xff]
    antiquewhite:         [0xfa,0xeb,0xd7]
    aqua:                 [0x00,0xff,0xff]
    aquamarine:           [0x7f,0xff,0xd4]
    azure:                [0xf0,0xff,0xff]
    beige:                [0xf5,0xf5,0xdc]
    bisque:               [0xff,0xe4,0xc4]
    black:                [0x00,0x00,0x00]
    blanchedalmond:       [0xff,0xeb,0xcd]
    blue:                 [0x00,0x00,0xff]
    blueviolet:           [0x8a,0x2b,0xe2]
    brown:                [0xa5,0x2a,0x2a]
    burlywood:            [0xde,0xb8,0x87]
    cadetblue:            [0x5f,0x9e,0xa0]
    chartreuse:           [0x7f,0xff,0x00]
    chocolate:            [0xd2,0x69,0x1e]
    coral:                [0xff,0x7f,0x50]
    cornflowerblue:       [0x64,0x95,0xed]
    cornsilk:             [0xff,0xf8,0xdc]
    crimson:              [0xdc,0x14,0x3c]
    cyan:                 [0x00,0xff,0xff]
    darkblue:             [0x00,0x00,0x8b]
    darkcyan:             [0x00,0x8b,0x8b]
    darkgoldenrod:        [0xb8,0x86,0x0b]
    darkgray:             [0xa9,0xa9,0xa9]
    darkgrey:             [0xa9,0xa9,0xa9]
    darkgreen:            [0x00,0x64,0x00]
    darkkhaki:            [0xbd,0xb7,0x6b]
    darkmagenta:          [0x8b,0x00,0x8b]
    darkolivegreen:       [0x55,0x6b,0x2f]
    darkorange:           [0xff,0x8c,0x00]
    darkorchid:           [0x99,0x32,0xcc]
    darkred:              [0x8b,0x00,0x00]
    darksalmon:           [0xe9,0x96,0x7a]
    darkseagreen:         [0x8f,0xbc,0x8f]
    darkslateblue:        [0x48,0x3d,0x8b]
    darkslategray:        [0x2f,0x4f,0x4f]
    darkslategrey:        [0x2f,0x4f,0x4f]
    darkturquoise:        [0x00,0xce,0xd1]
    darkviolet:           [0x94,0x00,0xd3]
    deeppink:             [0xff,0x14,0x93]
    deepskyblue:          [0x00,0xbf,0xff]
    dimgray:              [0x69,0x69,0x69]
    dimgrey:              [0x69,0x69,0x69]
    dodgerblue:           [0x1e,0x90,0xff]
    firebrick:            [0xb2,0x22,0x22]
    floralwhite:          [0xff,0xfa,0xf0]
    forestgreen:          [0x22,0x8b,0x22]
    fuchsia:              [0xff,0x00,0xff]
    gainsboro:            [0xdc,0xdc,0xdc]
    ghostwhite:           [0xf8,0xf8,0xff]
    gold:                 [0xff,0xd7,0x00]
    goldenrod:            [0xda,0xa5,0x20]
    gray:                 [0x80,0x80,0x80]
    grey:                 [0x80,0x80,0x80]
    green:                [0x00,0x80,0x00]
    greenyellow:          [0xad,0xff,0x2f]
    honeydew:             [0xf0,0xff,0xf0]
    hotpink:              [0xff,0x69,0xb4]
    indianred:            [0xcd,0x5c,0x5c]
    indigo:               [0x4b,0x00,0x82]
    ivory:                [0xff,0xff,0xf0]
    khaki:                [0xf0,0xe6,0x8c]
    lavender:             [0xe6,0xe6,0xfa]
    lavenderblush:        [0xff,0xf0,0xf5]
    lawngreen:            [0x7c,0xfc,0x00]
    lemonchiffon:         [0xff,0xfa,0xcd]
    lightblue:            [0xad,0xd8,0xe6]
    lightcoral:           [0xf0,0x80,0x80]
    lightcyan:            [0xe0,0xff,0xff]
    lightgoldenrodyellow: [0xfa,0xfa,0xd2]
    lightgrey:            [0xd3,0xd3,0xd3]
    lightgray:            [0xd3,0xd3,0xd3]
    lightgreen:           [0x90,0xee,0x90]
    lightpink:            [0xff,0xb6,0xc1]
    lightsalmon:          [0xff,0xa0,0x7a]
    lightseagreen:        [0x20,0xb2,0xaa]
    lightskyblue:         [0x87,0xce,0xfa]
    lightslategray:       [0x77,0x88,0x99]
    lightslategrey:       [0x77,0x88,0x99]
    lightsteelblue:       [0xb0,0xc4,0xde]
    lightyellow:          [0xff,0xff,0xe0]
    lime:                 [0x00,0xff,0x00]
    limegreen:            [0x32,0xcd,0x32]
    linen:                [0xfa,0xf0,0xe6]
    mintcream:            [0xf5,0xff,0xfa]
    mistyrose:            [0xff,0xe4,0xe1]
    moccasin:             [0xff,0xe4,0xb5]
    navajowhite:          [0xff,0xde,0xad]
    navy:                 [0x00,0x00,0x80]
    oldlace:              [0xfd,0xf5,0xe6]
    olive:                [0x80,0x80,0x00]
    olivedrab:            [0x6b,0x8e,0x23]
    orange:               [0xff,0xa5,0x00]
    orangered:            [0xff,0x45,0x00]
    orchid:               [0xda,0x70,0xd6]
    palegoldenrod:        [0xee,0xe8,0xaa]
    palegreen:            [0x98,0xfb,0x98]
    paleturquoise:        [0xaf,0xee,0xee]
    palevioletred:        [0xd8,0x70,0x93]
    papayawhip:           [0xff,0xef,0xd5]
    peachpuff:            [0xff,0xda,0xb9]
    peru:                 [0xcd,0x85,0x3f]
    pink:                 [0xff,0xc0,0xcb]
    plum:                 [0xdd,0xa0,0xdd]
    powderblue:           [0xb0,0xe0,0xe6]
    purple:               [0x80,0x00,0x80]
    red:                  [0xff,0x00,0x00]
    rosybrown:            [0xbc,0x8f,0x8f]
    royalblue:            [0x41,0x69,0xe1]
    saddlebrown:          [0x8b,0x45,0x13]
    salmon:               [0xfa,0x80,0x72]
    sandybrown:           [0xf4,0xa4,0x60]
    seagreen:             [0x2e,0x8b,0x57]
    seashell:             [0xff,0xf5,0xee]
    sienna:               [0xa0,0x52,0x2d]
    silver:               [0xc0,0xc0,0xc0]
    skyblue:              [0x87,0xce,0xeb]
    slateblue:            [0x6a,0x5a,0xcd]
    slategray:            [0x70,0x80,0x90]
    slategrey:            [0x70,0x80,0x90]
    snow:                 [0xff,0xfa,0xfa]
    springgreen:          [0x00,0xff,0x7f]
    steelblue:            [0x46,0x82,0xb4]
    tan:                  [0xd2,0xb4,0x8c]
    teal:                 [0x00,0x80,0x80]
    thistle:              [0xd8,0xbf,0xd8]
    tomato:               [0xff,0x63,0x47]
    turquoise:            [0x40,0xe0,0xd0]
    violet:               [0xee,0x82,0xee]
    wheat:                [0xf5,0xde,0xb3]
    white:                [0xff,0xff,0xff]
    whitesmoke:           [0xf5,0xf5,0xf5]
    yellow:               [0xff,0xff,0x00]
    yellowgreen:          [0x9a,0xcd,0x32]

  a: null
  r: null
  g: null
  b: null

  constructor: (@r = 0, @g = 0, @b = 0, a) ->
    # all values are optional, just (r, g, b) is fine
    @a = a or ((if (a is 0) then 0 else 1))
  
  # Color string representation: e.g. 'rgba(255,165,0,1)'
  toString: ->
    "rgba(" + Math.round(@r) + "," + Math.round(@g) + "," + Math.round(@b) + "," + @a + ")"
  
  # Color copying:
  copy: ->
    new @constructor(@r, @g, @b, @a)
  
  # Color comparison:
  eq: (aColor) ->
    # ==
    aColor and @r is aColor.r and @g is aColor.g and @b is aColor.b
  
  
  # Color conversion (hsv):
  hsv: ->
    # ignore alpha
    rr = @r / 255
    gg = @g / 255
    bb = @b / 255
    max = Math.max(rr, gg, bb)
    min = Math.min(rr, gg, bb)
    h = max
    s = max
    v = max
    d = max - min
    s = (if max is 0 then 0 else d / max)
    if max is min
      h = 0
    else
      switch max
        when rr
          h = (gg - bb) / d + ((if gg < bb then 6 else 0))
        when gg
          h = (bb - rr) / d + 2
        when bb
          h = (rr - gg) / d + 4
      h /= 6
    [h, s, v]
  
  set_hsv: (h, s, v) ->
    # ignore alpha
    # h, s and v are to be within [0, 1]
    i = Math.floor(h * 6)
    f = h * 6 - i
    p = v * (1 - s)
    q = v * (1 - f * s)
    t = v * (1 - (1 - f) * s)
    switch i % 6
      when 0
        @r = v
        @g = t
        @b = p
      when 1
        @r = q
        @g = v
        @b = p
      when 2
        @r = p
        @g = v
        @b = t
      when 3
        @r = p
        @g = q
        @b = v
      when 4
        @r = t
        @g = p
        @b = v
      when 5
        @r = v
        @g = p
        @b = q
    @r *= 255
    @g *= 255
    @b *= 255
  
  
  # Color mixing:
  mixed: (proportion, otherColor) ->
    # answer a copy of this color mixed with another color, ignore alpha
    frac1 = Math.min(Math.max(proportion, 0), 1)
    frac2 = 1 - frac1
    new @constructor(
      @r * frac1 + otherColor.r * frac2,
      @g * frac1 + otherColor.g * frac2,
      @b * frac1 + otherColor.b * frac2)
  
  darker: (percent) ->
    # return an rgb-interpolated darker copy of me, ignore alpha
    fract = 0.8333
    fract = (100 - percent) / 100  if percent
    @mixed fract, new @constructor(0, 0, 0)
  
  lighter: (percent) ->
    # return an rgb-interpolated lighter copy of me, ignore alpha
    fract = 0.8333
    fract = (100 - percent) / 100  if percent
    @mixed fract, new @constructor(255, 255, 255)
  
  dansDarker: ->
    # return an hsv-interpolated darker copy of me, ignore alpha
    hsv = @hsv()
    result = new @constructor()
    vv = Math.max(hsv[2] - 0.16, 0)
    result.set_hsv hsv[0], hsv[1], vv
    result

  @transparent: ->
    return new @constructor(0,0,0,0)

  '''

# //////////////////////////////////////////////////////////

# these comments below needed to figure our dependencies between classes
# REQUIRES globalFunctions

# some morphs (for example ColorPaletteMorph
# or SliderMorph) can control a target
# and they have the same function to attach
# targets. Not worth having this in the
# whole Morph hierarchy, so... ideal use
# of mixins here.

ControllerMixin =
  # klass properties here:
  # none

  # instance properties to follow:
  onceAddedClassProperties: ->
    @addInstanceProperties
      setTarget: ->
        # get rid of any previous temporary
        # active menu because it's meant to be
        # out of view anyways, otherwise we show
        # its submorphs in the setTarget options
        # which is most probably not wanted.
        if world.activeMenu
          world.activeMenu = world.activeMenu.destroy()
        choices = world.plausibleTargetAndDestinationMorphs(@)
        if choices.length > 0
          menu = new MenuMorph(@, "choose target:")
          #choices.push @world()
          choices.forEach (each) =>
            menu.addItem each.toString().slice(0, 50), =>
              @setTargetSetter(each)
        else
          menu = new MenuMorph(@, "no targets available")
        menu.popUpAtHand()

# ColorPaletteMorph ///////////////////////////////////////////////////
# REQUIRES ControllerMixin

class ColorPaletteMorph extends Morph
  @augmentWith ControllerMixin

  target: null
  targetSetter: "color"
  choice: null

  constructor: (@target = null, sizePoint) ->
    super()
    @silentSetExtent sizePoint or new Point(80, 50)
  
  updateRendering: ->
    ext = @extent()
    @image = newCanvas(@extent().scaleBy pixelRatio)
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    @choice = new Color()
    for x in [0..ext.x]
      h = 360 * x / ext.x
      y = 0
      for y in [0..ext.y]
        l = 100 - (y / ext.y * 100)
        # see link below for alternatives on how to set a single
        # pixel color.
        # You should really be using putImageData of the whole buffer
        # here anyways. But this is clearer.
        # http://stackoverflow.com/questions/4899799/whats-the-best-way-to-set-a-single-pixel-in-an-html5-canvas
        context.fillStyle = "hsl(" + h + ",100%," + l + "%)"
        context.fillRect x, y, 1, 1
  
  mouseMove: (pos) ->
    @choice = @getPixelColor(pos)
    @updateTarget()
  
  mouseDownLeft: (pos) ->
    @choice = @getPixelColor(pos)
    @updateTarget()
  
  updateTarget: ->
    if @target instanceof Morph and @choice?
      if @target[@targetSetter] instanceof Function
        @target[@targetSetter] @choice
      else
        @target[@targetSetter] = @choice
        @target.updateRendering()
        @target.changed()
  
    
  # ColorPaletteMorph menu:
  developersMenu: ->
    menu = super()
    menu.addLine()
    menu.addItem "set target", (->@setTarget()), "choose another morph\nwhose color property\n will be" + " controlled by this one"
    menu
  
  # setTarget: -> taken form the ControllerMixin
  
  setTargetSetter: (theTarget) ->
    choices = theTarget.colorSetters()
    menu = new MenuMorph(@, "choose target property:")
    choices.forEach (each) =>
      menu.addItem each, =>
        @target = theTarget
        @targetSetter = each
    if choices.length == 0
      menu = new MenuMorph(@, "no target properties available")
    menu.popUpAtHand()

  @coffeeScriptSourceOfThisClass: '''
# ColorPaletteMorph ///////////////////////////////////////////////////
# REQUIRES ControllerMixin

class ColorPaletteMorph extends Morph
  @augmentWith ControllerMixin

  target: null
  targetSetter: "color"
  choice: null

  constructor: (@target = null, sizePoint) ->
    super()
    @silentSetExtent sizePoint or new Point(80, 50)
  
  updateRendering: ->
    ext = @extent()
    @image = newCanvas(@extent().scaleBy pixelRatio)
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    @choice = new Color()
    for x in [0..ext.x]
      h = 360 * x / ext.x
      y = 0
      for y in [0..ext.y]
        l = 100 - (y / ext.y * 100)
        # see link below for alternatives on how to set a single
        # pixel color.
        # You should really be using putImageData of the whole buffer
        # here anyways. But this is clearer.
        # http://stackoverflow.com/questions/4899799/whats-the-best-way-to-set-a-single-pixel-in-an-html5-canvas
        context.fillStyle = "hsl(" + h + ",100%," + l + "%)"
        context.fillRect x, y, 1, 1
  
  mouseMove: (pos) ->
    @choice = @getPixelColor(pos)
    @updateTarget()
  
  mouseDownLeft: (pos) ->
    @choice = @getPixelColor(pos)
    @updateTarget()
  
  updateTarget: ->
    if @target instanceof Morph and @choice?
      if @target[@targetSetter] instanceof Function
        @target[@targetSetter] @choice
      else
        @target[@targetSetter] = @choice
        @target.updateRendering()
        @target.changed()
  
    
  # ColorPaletteMorph menu:
  developersMenu: ->
    menu = super()
    menu.addLine()
    menu.addItem "set target", (->@setTarget()), "choose another morph\nwhose color property\n will be" + " controlled by this one"
    menu
  
  # setTarget: -> taken form the ControllerMixin
  
  setTargetSetter: (theTarget) ->
    choices = theTarget.colorSetters()
    menu = new MenuMorph(@, "choose target property:")
    choices.forEach (each) =>
      menu.addItem each, =>
        @target = theTarget
        @targetSetter = each
    if choices.length == 0
      menu = new MenuMorph(@, "no target properties available")
    menu.popUpAtHand()
  '''

# ColorPickerMorph ///////////////////////////////////////////////////

class ColorPickerMorph extends Morph

  choice: null

  constructor: (defaultColor) ->
    @choice = defaultColor or new Color(255, 255, 255)
    super()
    @color = new Color(255, 255, 255)
    @silentSetExtent new Point(80, 80)
    @buildSubmorphs()
  
  buildSubmorphs: ->
    @destroyAll()
    @children = []
    @feedback = new RectangleMorph(new Point(20, 20), @choice)
    cpal = new ColorPaletteMorph(@feedback, new Point(@width(), 50))
    gpal = new GrayPaletteMorph(@feedback, new Point(@width(), 5))
    cpal.setPosition @bounds.origin
    @add cpal
    gpal.setPosition cpal.bottomLeft()
    @add gpal
    x = (gpal.left() + Math.floor((gpal.width() - @feedback.width()) / 2))
    y = gpal.bottom() + Math.floor((@bottom() - gpal.bottom() - @feedback.height()) / 2)
    @feedback.setPosition new Point(x, y)
    @add @feedback
  
  getColor: ->
    @feedback.color
  
  rootForGrab: ->
    @

  @coffeeScriptSourceOfThisClass: '''
# ColorPickerMorph ///////////////////////////////////////////////////

class ColorPickerMorph extends Morph

  choice: null

  constructor: (defaultColor) ->
    @choice = defaultColor or new Color(255, 255, 255)
    super()
    @color = new Color(255, 255, 255)
    @silentSetExtent new Point(80, 80)
    @buildSubmorphs()
  
  buildSubmorphs: ->
    @destroyAll()
    @children = []
    @feedback = new RectangleMorph(new Point(20, 20), @choice)
    cpal = new ColorPaletteMorph(@feedback, new Point(@width(), 50))
    gpal = new GrayPaletteMorph(@feedback, new Point(@width(), 5))
    cpal.setPosition @bounds.origin
    @add cpal
    gpal.setPosition cpal.bottomLeft()
    @add gpal
    x = (gpal.left() + Math.floor((gpal.width() - @feedback.width()) / 2))
    y = gpal.bottom() + Math.floor((@bottom() - gpal.bottom() - @feedback.height()) / 2)
    @feedback.setPosition new Point(x, y)
    @add @feedback
  
  getColor: ->
    @feedback.color
  
  rootForGrab: ->
    @
  '''

# //////////////////////////////////////////////////////////
#      THIS MIXIN IS TEMPORARY. JUST STARTED IT.
# //////////////////////////////////////////////////////////

# these comments below needed to figure our dependencies between classes
# REQUIRES globalFunctions

#   1) a container has potentially a background and
#   2) some padding
#   3) it resizes itself so to *at least contain* all the morphs attached to it (i.e. it could be bigger).
# It doesn’t need to be rectangular.
# [TODO] Also it can draw a border of its own cause of the padding, you can add enough padding so the border is drawn correctly, maybe the padding can be automatically determined based on the border color.

ContainerMixin =
  # klass properties here:
  # none

  # instance properties to follow:
  onceAddedClassProperties: ->
    @addInstanceProperties
      setTarget: ->
        # get rid of any previous temporary
        # active menu because it's meant to be
        # out of view anyways, otherwise we show
        # its submorphs in the setTarget options
        # which is most probably not wanted.
        if world.activeMenu
          world.activeMenu = world.activeMenu.destroy()
        choices = world.plausibleTargetAndDestinationMorphs(@)
        if choices.length > 0
          menu = new MenuMorph(@, "choose target:")
          #choices.push @world()
          choices.forEach (each) =>
            menu.addItem each.toString().slice(0, 50), =>
              @setTargetSetter(each)
        else
          menu = new MenuMorph(@, "no targets available")
        menu.popUpAtHand()

  submorphBounds: ->
    result = null
    if @children.length
      result = @children[0].bounds
      @children.forEach (child) ->
        result = result.merge(child.boundsIncludingChildren())
    result
    
  adjustBounds: ->
    newBounds = @submorphBounds()
    if newBounds
      if @padding?
        newBounds = newBounds.expandBy(@padding)
    else
      newBounds = @bounds.copy()

    unless @bounds.eq(newBounds)
      @bounds = newBounds
      @changed()
      @updateRendering()

#| FrameMorph //////////////////////////////////////////////////////////
#| 
#| I clip my submorphs at my bounds. Which potentially saves a lot of redrawing
#| 
#| and event handling. 
#| 
#| It's a good idea to use me whenever it's clear that there is a  
#| 
#| "container"/"contained" scenario going on.

class FrameMorph extends Morph

  scrollFrame: null
  extraPadding: 0

  # if this frame belongs to a scrollFrame, then
  # the @scrollFrame points to it
  constructor: (@scrollFrame = null) ->
    super()
    @color = new Color(255, 250, 245)
    @acceptsDrops = true
    if @scrollFrame
      @isDraggable = false
      @noticesTransparentClick = false

  setColor: (aColor) ->
    # keep in synch the value of the container scrollFrame
    # if there is one. Note that the container scrollFrame
    # is actually not painted.
    if @scrollFrame
      @scrollFrame.color = aColor
    super(aColor)

  setAlphaScaled: (alpha) ->
    # keep in synch the value of the container scrollFrame
    # if there is one. Note that the container scrollFrame
    # is actually not painted.
    if @scrollFrame
      @scrollFrame.alpha = @calculateAlphaScaled(alpha)
    super(alpha)

  # used for example:
  # - to determine which morphs you can attach a morph to
  # - for a SliderMorph's "set target" so you can change properties of another Morph
  # - by the HandleMorph when you attach it to some other morph
  # Note that this method has a slightly different
  # version in Morph (because it doesn't clip)
  plausibleTargetAndDestinationMorphs: (theMorph) ->
    # find if I intersect theMorph,
    # then check my children recursively
    # exclude me if I'm a child of theMorph
    # (cause it's usually odd to attach a Morph
    # to one of its submorphs or for it to
    # control the properties of one of its submorphs)
    result = []
    if !@isMinimised and
        @isVisible and
        !theMorph.containedInParentsOf(@) and
        @bounds.intersects(theMorph.bounds)
      result = [@]

    # Since the FrameMorph clips its children
    # at its boundary, hence we need
    # to check that we don't consider overlaps with
    # morphs contained in this frame that are clipped and
    # hence *actually* not overlapping with theMorph.
    # So continue checking the children only if the
    # frame itself actually overlaps.
    if @bounds.intersects(theMorph.bounds)
      @children.forEach (child) ->
        result = result.concat(child.plausibleTargetAndDestinationMorphs(theMorph))

    return result
  
  # frames clip at their boundaries
  # so there is no need to do a deep
  # traversal to find the bounds.
  boundsIncludingChildren: ->
    shadow = @getShadow()
    if shadow?
      return @bounds.merge(shadow.bounds)
    @bounds
  
  recursivelyBlit: (aCanvas, clippingRectangle = @bounds) ->
    return null  unless (!@isMinimised and @isVisible)

    # a FrameMorph has the special property that all of its children
    # are actually inside its boundary.
    # This allows
    # us to avoid the further traversal of potentially
    # many many morphs if we see that the rectangle we
    # want to blit is outside its frame.
    # If the rectangle we want to blit is inside the frame
    # then we do have to continue traversing all the
    # children of the Frame.

    # This is why as well it's good to use FrameMorphs whenever
    # it's clear that there is a "container" case. Think
    # for example that you could stick a small
    # RectangleMorph (not a Frame) on the desktop and then
    # attach a thousand
    # CircleBoxMorphs on it.
    # Say that the circles are all inside the rectangle,
    # apart from four that are at the corners of the world.
    # that's a nightmare scenegraph
    # to *completely* traverse for *any* broken rectangle
    # anywhere on the screen.
    # The traversal is complete because a) Morphic doesn't
    # assume that the rectangle clips its children and
    # b) the bounding rectangle (which currently is not
    # efficiently calculated anyways) is the whole screen.
    # So the children could be anywhere and need to be all
    # checked for damaged areas to repaint.
    # If the RectangleMorph is made into a frame, one can
    # avoid the traversal for any broken rectangle not
    # overlapping it.

    # Also note that in theory you could stop recursion on any
    # FrameMorph completely covered by a large opaque morph
    # (or on any Morph which boundsIncludingChildren are completely
    # covered, for that matter). You could
    # keep for example a list of the top n biggest opaque morphs
    # (say, frames and rectangles)
    # and check that case while you traverse the list.
    # (see https://github.com/davidedc/Zombie-Kernel/issues/149 )
    
    # the part to be redrawn could be outside the frame entirely,
    # in which case we can stop going down the morphs inside the frame
    # since the whole point of the frame is to clip everything to a specific
    # rectangle.
    # So, check which part of the Frame should be redrawn:
    dirtyPartOfFrame = @bounds.intersect(clippingRectangle)
    
    # if there is no dirty part in the frame then do nothing
    return null if dirtyPartOfFrame.isEmpty()
    
    # this draws the background of the frame itself, which could
    # contain an image or a pentrail
    @blit aCanvas, dirtyPartOfFrame
    
    @children.forEach (child) =>
      if child instanceof ShadowMorph
        child.recursivelyBlit aCanvas, clippingRectangle
      else
        child.recursivelyBlit aCanvas, dirtyPartOfFrame
  
  
  # FrameMorph scrolling optimization:
  moveBy: (delta) ->
    #console.log "moving all morphs in the frame"
    @changed()
    @bounds = @bounds.translateBy(delta)
    @children.forEach (child) ->
      child.silentMoveBy delta
    @changed()
  
  
  # FrameMorph scrolling support:
  submorphBounds: ->
    result = null
    if @children.length
      result = @children[0].bounds
      @children.forEach (child) ->
        result = result.merge(child.boundsIncludingChildren())
    result
  
  # Should it be in the scrollframe rather than in Frame?
  keepInScrollFrame: ->
    if !@scrollFrame?
      return null
    if @left() > @scrollFrame.left()
      @moveBy new Point(@scrollFrame.left() - @left(), 0)
    if @right() < @scrollFrame.right()
      @moveBy new Point(@scrollFrame.right() - @right(), 0)  
    if @top() > @scrollFrame.top()
      @moveBy new Point(0, @scrollFrame.top() - @top())  
    if @bottom() < @scrollFrame.bottom()
      @moveBy 0, new Point(@scrollFrame.bottom() - @bottom(), 0)
  
  adjustBounds: ->
    if !@scrollFrame?
      return null

    # if FrameMorph is of type isTextLineWrapping
    # it means that you don't want the TextMorph to
    # extend indefinitely as you are typing. Rather,
    # the width will be constrained and the text will
    # wrap.
    if @scrollFrame.isTextLineWrapping
      debugger
      @children.forEach (morph) =>
        if morph instanceof TextMorph
          totalPadding =  2*(@scrollFrame.extraPadding + @scrollFrame.padding)
          # this re-layouts the text to fit the width.
          # The new height of the TextMorph will then be used
          # to redraw the vertical slider.
          morph.setWidth @width() - totalPadding
          morph.maxWidth = @width() - totalPadding
          @setHeight Math.max(morph.height(), @scrollFrame.height() - totalPadding)

    subBounds = @submorphBounds()
    if subBounds
      newBounds = subBounds.expandBy(@scrollFrame.padding + @scrollFrame.extraPadding).growBy(@scrollFrame.growth).merge(@scrollFrame.bounds)
    else
      newBounds = @scrollFrame.bounds.copy()
    unless @bounds.eq(newBounds)
      @bounds = newBounds
      @updateRendering()
      @keepInScrollFrame()
    @scrollFrame.adjustScrollBars()
  
  
  # FrameMorph dragging & dropping of contents:
  reactToDropOf: ->
    @adjustBounds()
  
  reactToGrabOf: ->
    @adjustBounds()
  
    
  # FrameMorph menus:
  developersMenu: ->
    menu = super()
    if @children.length
      menu.addLine()
      menu.addItem "move all inside", (->@keepAllSubmorphsWithin()), "keep all submorphs\nwithin and visible"
    menu
  
  keepAllSubmorphsWithin: ->
    @children.forEach (m) =>
      m.keepWithin @

  @coffeeScriptSourceOfThisClass: '''
#| FrameMorph //////////////////////////////////////////////////////////
#| 
#| I clip my submorphs at my bounds. Which potentially saves a lot of redrawing
#| 
#| and event handling. 
#| 
#| It's a good idea to use me whenever it's clear that there is a  
#| 
#| "container"/"contained" scenario going on.

class FrameMorph extends Morph

  scrollFrame: null
  extraPadding: 0

  # if this frame belongs to a scrollFrame, then
  # the @scrollFrame points to it
  constructor: (@scrollFrame = null) ->
    super()
    @color = new Color(255, 250, 245)
    @acceptsDrops = true
    if @scrollFrame
      @isDraggable = false
      @noticesTransparentClick = false

  setColor: (aColor) ->
    # keep in synch the value of the container scrollFrame
    # if there is one. Note that the container scrollFrame
    # is actually not painted.
    if @scrollFrame
      @scrollFrame.color = aColor
    super(aColor)

  setAlphaScaled: (alpha) ->
    # keep in synch the value of the container scrollFrame
    # if there is one. Note that the container scrollFrame
    # is actually not painted.
    if @scrollFrame
      @scrollFrame.alpha = @calculateAlphaScaled(alpha)
    super(alpha)

  # used for example:
  # - to determine which morphs you can attach a morph to
  # - for a SliderMorph's "set target" so you can change properties of another Morph
  # - by the HandleMorph when you attach it to some other morph
  # Note that this method has a slightly different
  # version in Morph (because it doesn't clip)
  plausibleTargetAndDestinationMorphs: (theMorph) ->
    # find if I intersect theMorph,
    # then check my children recursively
    # exclude me if I'm a child of theMorph
    # (cause it's usually odd to attach a Morph
    # to one of its submorphs or for it to
    # control the properties of one of its submorphs)
    result = []
    if !@isMinimised and
        @isVisible and
        !theMorph.containedInParentsOf(@) and
        @bounds.intersects(theMorph.bounds)
      result = [@]

    # Since the FrameMorph clips its children
    # at its boundary, hence we need
    # to check that we don't consider overlaps with
    # morphs contained in this frame that are clipped and
    # hence *actually* not overlapping with theMorph.
    # So continue checking the children only if the
    # frame itself actually overlaps.
    if @bounds.intersects(theMorph.bounds)
      @children.forEach (child) ->
        result = result.concat(child.plausibleTargetAndDestinationMorphs(theMorph))

    return result
  
  # frames clip at their boundaries
  # so there is no need to do a deep
  # traversal to find the bounds.
  boundsIncludingChildren: ->
    shadow = @getShadow()
    if shadow?
      return @bounds.merge(shadow.bounds)
    @bounds
  
  recursivelyBlit: (aCanvas, clippingRectangle = @bounds) ->
    return null  unless (!@isMinimised and @isVisible)

    # a FrameMorph has the special property that all of its children
    # are actually inside its boundary.
    # This allows
    # us to avoid the further traversal of potentially
    # many many morphs if we see that the rectangle we
    # want to blit is outside its frame.
    # If the rectangle we want to blit is inside the frame
    # then we do have to continue traversing all the
    # children of the Frame.

    # This is why as well it's good to use FrameMorphs whenever
    # it's clear that there is a "container" case. Think
    # for example that you could stick a small
    # RectangleMorph (not a Frame) on the desktop and then
    # attach a thousand
    # CircleBoxMorphs on it.
    # Say that the circles are all inside the rectangle,
    # apart from four that are at the corners of the world.
    # that's a nightmare scenegraph
    # to *completely* traverse for *any* broken rectangle
    # anywhere on the screen.
    # The traversal is complete because a) Morphic doesn't
    # assume that the rectangle clips its children and
    # b) the bounding rectangle (which currently is not
    # efficiently calculated anyways) is the whole screen.
    # So the children could be anywhere and need to be all
    # checked for damaged areas to repaint.
    # If the RectangleMorph is made into a frame, one can
    # avoid the traversal for any broken rectangle not
    # overlapping it.

    # Also note that in theory you could stop recursion on any
    # FrameMorph completely covered by a large opaque morph
    # (or on any Morph which boundsIncludingChildren are completely
    # covered, for that matter). You could
    # keep for example a list of the top n biggest opaque morphs
    # (say, frames and rectangles)
    # and check that case while you traverse the list.
    # (see https://github.com/davidedc/Zombie-Kernel/issues/149 )
    
    # the part to be redrawn could be outside the frame entirely,
    # in which case we can stop going down the morphs inside the frame
    # since the whole point of the frame is to clip everything to a specific
    # rectangle.
    # So, check which part of the Frame should be redrawn:
    dirtyPartOfFrame = @bounds.intersect(clippingRectangle)
    
    # if there is no dirty part in the frame then do nothing
    return null if dirtyPartOfFrame.isEmpty()
    
    # this draws the background of the frame itself, which could
    # contain an image or a pentrail
    @blit aCanvas, dirtyPartOfFrame
    
    @children.forEach (child) =>
      if child instanceof ShadowMorph
        child.recursivelyBlit aCanvas, clippingRectangle
      else
        child.recursivelyBlit aCanvas, dirtyPartOfFrame
  
  
  # FrameMorph scrolling optimization:
  moveBy: (delta) ->
    #console.log "moving all morphs in the frame"
    @changed()
    @bounds = @bounds.translateBy(delta)
    @children.forEach (child) ->
      child.silentMoveBy delta
    @changed()
  
  
  # FrameMorph scrolling support:
  submorphBounds: ->
    result = null
    if @children.length
      result = @children[0].bounds
      @children.forEach (child) ->
        result = result.merge(child.boundsIncludingChildren())
    result
  
  # Should it be in the scrollframe rather than in Frame?
  keepInScrollFrame: ->
    if !@scrollFrame?
      return null
    if @left() > @scrollFrame.left()
      @moveBy new Point(@scrollFrame.left() - @left(), 0)
    if @right() < @scrollFrame.right()
      @moveBy new Point(@scrollFrame.right() - @right(), 0)  
    if @top() > @scrollFrame.top()
      @moveBy new Point(0, @scrollFrame.top() - @top())  
    if @bottom() < @scrollFrame.bottom()
      @moveBy 0, new Point(@scrollFrame.bottom() - @bottom(), 0)
  
  adjustBounds: ->
    if !@scrollFrame?
      return null

    # if FrameMorph is of type isTextLineWrapping
    # it means that you don't want the TextMorph to
    # extend indefinitely as you are typing. Rather,
    # the width will be constrained and the text will
    # wrap.
    if @scrollFrame.isTextLineWrapping
      debugger
      @children.forEach (morph) =>
        if morph instanceof TextMorph
          totalPadding =  2*(@scrollFrame.extraPadding + @scrollFrame.padding)
          # this re-layouts the text to fit the width.
          # The new height of the TextMorph will then be used
          # to redraw the vertical slider.
          morph.setWidth @width() - totalPadding
          morph.maxWidth = @width() - totalPadding
          @setHeight Math.max(morph.height(), @scrollFrame.height() - totalPadding)

    subBounds = @submorphBounds()
    if subBounds
      newBounds = subBounds.expandBy(@scrollFrame.padding + @scrollFrame.extraPadding).growBy(@scrollFrame.growth).merge(@scrollFrame.bounds)
    else
      newBounds = @scrollFrame.bounds.copy()
    unless @bounds.eq(newBounds)
      @bounds = newBounds
      @updateRendering()
      @keepInScrollFrame()
    @scrollFrame.adjustScrollBars()
  
  
  # FrameMorph dragging & dropping of contents:
  reactToDropOf: ->
    @adjustBounds()
  
  reactToGrabOf: ->
    @adjustBounds()
  
    
  # FrameMorph menus:
  developersMenu: ->
    menu = super()
    if @children.length
      menu.addLine()
      menu.addItem "move all inside", (->@keepAllSubmorphsWithin()), "keep all submorphs\nwithin and visible"
    menu
  
  keepAllSubmorphsWithin: ->
    @children.forEach (m) =>
      m.keepWithin @
  '''

# GrayPaletteMorph ///////////////////////////////////////////////////

class GrayPaletteMorph extends ColorPaletteMorph

  constructor: (@target = null, sizePoint) ->
    super @target, sizePoint or new Point(80, 10)
  
  updateRendering: ->
    ext = @extent()
    @image = newCanvas(@extent().scaleBy pixelRatio)
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    @choice = new Color()
    gradient = context.createLinearGradient(0, 0, ext.x, ext.y)
    gradient.addColorStop 0, "black"
    gradient.addColorStop 1, "white"
    context.fillStyle = gradient
    context.fillRect 0, 0, ext.x, ext.y

  @coffeeScriptSourceOfThisClass: '''
# GrayPaletteMorph ///////////////////////////////////////////////////

class GrayPaletteMorph extends ColorPaletteMorph

  constructor: (@target = null, sizePoint) ->
    super @target, sizePoint or new Point(80, 10)
  
  updateRendering: ->
    ext = @extent()
    @image = newCanvas(@extent().scaleBy pixelRatio)
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    @choice = new Color()
    gradient = context.createLinearGradient(0, 0, ext.x, ext.y)
    gradient.addColorStop 0, "black"
    gradient.addColorStop 1, "white"
    context.fillStyle = gradient
    context.fillRect 0, 0, ext.x, ext.y
  '''

# HandMorph ///////////////////////////////////////////////////////////

# The mouse cursor. Note that it's not a child of the WorldMorph, this Morph
# is never added to any other morph. [TODO] Find out why and write explanation.
# Not to be confused with the HandleMorph

class HandMorph extends Morph

  world: null
  mouseButton: null
  # used for example to check that
  # mouseDown and mouseUp happen on the
  # same Morph (otherwise clicks happen for
  # example when resizing a button via the
  # handle)
  mouseDownMorph: null
  morphToGrab: null
  grabOrigin: null
  mouseOverList: null
  temporaries: null
  touchHoldTimeout: null

  constructor: (@world) ->
    @mouseOverList = []
    @temporaries = []
    super()
    @bounds = new Rectangle()
  
  changed: ->
    if @world?
      b = @boundsIncludingChildren()
      if !b.extent().eq(new Point())
        @world.broken.push @boundsIncludingChildren().spread()
  
  
  # HandMorph navigation:
  topMorphUnderPointer: ->
    result = @world.topMorphSuchThat (m) =>
      m.visibleBounds().containsPoint(@bounds.origin) and
        !m.isMinimised and m.isVisible and (m.noticesTransparentClick or
        (not m.isTransparentAt(@bounds.origin))) and (m not instanceof ShadowMorph)
    if result?
      return result
    else
      return @world

  menuAtPointer: ->
    result = @world.topMorphSuchThat (m) =>
      m.visibleBounds().containsPoint(@bounds.origin) and
        !m.isMinimised and m.isVisible and (m.noticesTransparentClick or
        (not m.isTransparentAt(@bounds.origin))) and (m instanceof MenuMorph)
    return result

  leftOrRightClickOnMenuItemWithText: (whichMouseButtonPressed, textLabelOfClickedItem, textLabelOccurrenceNumber) ->
    itemToTrigger = @world.activeMenu.nthChildSuchThat textLabelOccurrenceNumber, (m) ->
      m.labelString == textLabelOfClickedItem

    # these three are checks and actions that normally
    # would happen on MouseDown event, but we
    # removed that event as we collapsed the down and up
    # into this colasesced higher-level event,
    # but we still need to make these checks and actions
    @destroyActiveMenuIfHandHasNotActionedIt itemToTrigger
    @destroyActiveHandleIfHandHasNotActionedIt itemToTrigger
    @stopEditingIfActionIsElsewhere itemToTrigger

    if whichMouseButtonPressed == "left"
      itemToTrigger.mouseClickLeft()
    else if whichMouseButtonPressed == "right"
      @openContextMenuAtPointer itemToTrigger.children[0]


  openContextMenuAtPointer: (morphTheMenuIsAbout) ->
    # note that the morphs that the menu
    # belongs to might not be under the mouse.
    # It usually is, but in cases
    # where a system test is playing against
    # a world setup that has varied since the
    # recording, this could be the case.

    # these three are checks and actions that normally
    # would happen on MouseDown event, but we
    # removed that event as we collapsed the down and up
    # into this colasesced higher-level event,
    # but we still need to make these checks and actions
    @destroyActiveMenuIfHandHasNotActionedIt morphTheMenuIsAbout
    @destroyActiveHandleIfHandHasNotActionedIt morphTheMenuIsAbout
    @stopEditingIfActionIsElsewhere morphTheMenuIsAbout

    contextMenu = morphTheMenuIsAbout.contextMenu()
    while (not contextMenu) and morphTheMenuIsAbout.parent
      morphTheMenuIsAbout = morphTheMenuIsAbout.parent
      contextMenu = morphTheMenuIsAbout.contextMenu()

    if contextMenu 
      contextMenu.popUpAtHand() 

  #
  #    alternative -  more elegant and possibly more
  #	performant - solution for topMorphUnderPointer.
  #	Has some issues, commented out for now
  #
  #HandMorph.prototype.topMorphUnderPointer = function () {
  #	var myself = this;
  #	return this.world.topMorphSuchThat(function (m) {
  #		return m.visibleBounds().containsPoint(myself.bounds.origin) &&
  #			!m.isMinimised &&
  #     m.isVisible &&
  #			(m.noticesTransparentClick ||
  #				(! m.isTransparentAt(myself.bounds.origin))) &&
  #			(! (m instanceof ShadowMorph));
  #	});
  #};
  #


  # not used in ZK yet
  allMorphsAtPointer: ->
    return @world.collectAllChildrenBottomToTopSuchThat (m) =>
      !m.isMinimised and m.isVisible and m.visibleBounds().containsPoint(@bounds.origin)
  
  
  
  # HandMorph dragging and dropping:
  #
  #	drag 'n' drop events, method(arg) -> receiver:
  #
  #		prepareToBeGrabbed(handMorph) -> grabTarget
  #		reactToGrabOf(grabbedMorph) -> oldParent
  #		wantsDropOf(morphToDrop) ->  newParent
  #		justDropped(handMorph) -> droppedMorph
  #		reactToDropOf(droppedMorph, handMorph) -> newParent
  #
  dropTargetFor: (aMorph) ->
    target = @topMorphUnderPointer()
    target = target.parent  until target.wantsDropOf(aMorph)
    target
  
  grab: (aMorph) ->
    oldParent = aMorph.parent
    return null  if aMorph instanceof WorldMorph
    if !@children.length
      @world.stopEditing()
      @grabOrigin = aMorph.situation()
      aMorph.prepareToBeGrabbed @  if aMorph.prepareToBeGrabbed
      @add aMorph
      # you must add the shadow
      # after the morph has been added
      # because "@add aMorph" causes
      # the morph to be painted potentially
      # for the first time.
      # The shadow needs the image of the
      # morph to make the shadow, so
      # this is why we add the shadow after
      # the morph has been added.
      aMorph.addShadow()
      @changed()
      oldParent.reactToGrabOf aMorph  if oldParent and oldParent.reactToGrabOf
  
  drop: ->
    if @children.length
      morphToDrop = @children[0]
      target = @dropTargetFor(morphToDrop)
      @changed()
      target.add morphToDrop
      morphToDrop.changed()
      morphToDrop.removeShadow()
      @children = []
      @setExtent new Point()
      morphToDrop.justDropped @  if morphToDrop.justDropped
      target.reactToDropOf morphToDrop, @  if target.reactToDropOf
      @dragOrigin = null
  
  # HandMorph event dispatching:
  #
  #    mouse events:
  #
  #		mouseDownLeft
  #		mouseDownRight
  #		mouseClickLeft
  #		mouseClickRight
  #   mouseDoubleClick
  #		mouseEnter
  #		mouseLeave
  #		mouseEnterDragging
  #		mouseLeaveDragging
  #		mouseMove
  #		mouseScroll
  #
  # Note that some handlers don't want the event but the
  # interesting parameters of the event. This is because
  # the testing harness only stores the interesting parameters
  # rather than a multifaceted and sometimes browser-specific
  # event object.

  destroyActiveHandleIfHandHasNotActionedIt: (actionedMorph) ->
    if @world.activeHandle?
      if actionedMorph isnt @world.activeHandle
        @world.activeHandle = @world.activeHandle.destroy()    

  destroyActiveMenuIfHandHasNotActionedIt: (actionedMorph) ->
    if @world.activeMenu?
      unless @world.activeMenu.containedInParentsOf(actionedMorph)
        # if there is a menu open and the user clicked on
        # something that is not part of the menu then
        # destroy the menu 
        @world.activeMenu = @world.activeMenu.destroy()
      else
        clearInterval @touchHoldTimeout

  stopEditingIfActionIsElsewhere: (actionedMorph) ->
    if @world.caret?
      # there is a caret on the screen
      # depending on what the user is clicking on,
      # we might need to close an ongoing edit
      # operation, which means deleting the
      # caret and un-selecting anything that was selected.
      # Note that we don't want to interrupt an edit
      # if the user is invoking/clicking on anything
      # inside a menu, because the invoked function
      # might do something with the selection
      # (for example doSelection takes the current selection).
      if actionedMorph isnt @world.caret.target
        # user clicked on something other than what the
        # caret is attached to
        if @world.activeMenu?
          unless @world.activeMenu.containedInParentsOf(actionedMorph)
            # only dismiss editing if the actionedMorph the user
            # clicked on is not part of a menu.
            @world.stopEditing()
        # there is no menu at all, in which case
        # we know there was an editing operation going
        # on that we need to stop
        else
          @world.stopEditing()

  processMouseDown: (button, ctrlKey) ->
    @destroyTemporaries()
    @morphToGrab = null
    # check whether we are in the middle
    # of a drag/drop operation
    if @children.length
      @drop()
      @mouseButton = null
    else
      morph = @topMorphUnderPointer()
      @destroyActiveMenuIfHandHasNotActionedIt morph
      @destroyActiveHandleIfHandHasNotActionedIt morph
      @stopEditingIfActionIsElsewhere morph

      @morphToGrab = morph.rootForGrab()  unless morph.mouseMove
      if button is 2 or ctrlKey
        @mouseButton = "right"
        actualClick = "mouseDownRight"
        expectedClick = "mouseClickRight"
      else
        @mouseButton = "left"
        actualClick = "mouseDownLeft"
        expectedClick = "mouseClickLeft"

      @mouseDownMorph = morph
      @mouseDownMorph = @mouseDownMorph.parent  until @mouseDownMorph[expectedClick]
      morph = morph.parent  until morph[actualClick]
      morph[actualClick] @bounds.origin
  
  # touch events, see:
  # https://developer.apple.com/library/safari/documentation/appleapplications/reference/safariwebcontent/HandlingEvents/HandlingEvents.html
  # A long touch emulates a right click. This is done via
  # setting a timer 400ms after the touch which triggers
  # a right mouse click. Any touch event before then just
  # resets the timer, so one has to hold the finger in
  # position for the right click to happen.
  processTouchStart: (event) ->
    event.preventDefault()
    WorldMorph.preferencesAndSettings.isTouchDevice = true
    clearInterval @touchHoldTimeout
    if event.touches.length is 1
      # simulate mouseRightClick
      @touchHoldTimeout = setInterval(=>
        @processMouseDown 2 # button 2 is the right one
        @processMouseUp 2 # button 2 is the right one, we don't use this parameter
        event.preventDefault() # I don't think that this is needed
        clearInterval @touchHoldTimeout
      , 400)
      @processMouseMove event.touches[0].pageX, event.touches[0].pageY # update my position
      @processMouseDown 0 # button zero is the left button
  
  processTouchMove: (event) ->
    # Prevent scrolling on this element
    event.preventDefault()

    if event.touches.length is 1
      touch = event.touches[0]
      @processMouseMove touch.pageX, touch.pageY
      clearInterval @touchHoldTimeout
  
  processTouchEnd: (event) ->
    # note that the mouse down event handler
    # that is calling this method has ALREADY
    # added a mousdown command

    WorldMorph.preferencesAndSettings.isTouchDevice = true
    clearInterval @touchHoldTimeout
    @processMouseUp 0 # button zero is the left button, we don't use this parameter
  
   # note that the button param is not used,
   # but adding it for consistency...
   processMouseUp: (button) ->
    morph = @topMorphUnderPointer()
    alreadyRecordedLeftOrRightClickOnMenuItem = false
    @destroyTemporaries()
    if @children.length
      @drop()
    else
      # let's check if the user clicked on a menu item,
      # in which case we add a special dedicated command
      # [TODO] you need to do some of this only if you
      # are recording a test, it's worth saving
      # these steps...
      menuItemMorph = morph.parentThatIsA(MenuItemMorph)
      if menuItemMorph
        # we check whether the menuitem is actually part
        # of an activeMenu. Keep in mind you could have
        # detached a menuItem and placed it on any other
        # morph so you need to ascertain that you'll
        # find it in the activeMenu later on...
        if @world.activeMenu == menuItemMorph.parent
          labelString = menuItemMorph.labelString
          morphSpawningTheMenu = menuItemMorph.parent.parent
          occurrenceNumber = menuItemMorph.howManySiblingsBeforeMeSuchThat (m) ->
            m.labelString == labelString
          # this method below is also going to remove
          # the mouse down/up commands that have
          # recently/jsut been added.
          @world.systemTestsRecorderAndPlayer.addCommandLeftOrRightClickOnMenuItem(@mouseButton, labelString, occurrenceNumber + 1)
          alreadyRecordedLeftOrRightClickOnMenuItem = true
      if @mouseButton is "left"
        expectedClick = "mouseClickLeft"
      else
        expectedClick = "mouseClickRight"
        if @mouseButton
          if !alreadyRecordedLeftOrRightClickOnMenuItem
            # this being a right click, pop
            # up a menu as needed.
            @world.systemTestsRecorderAndPlayer.addOpenContextMenuCommand morph.uniqueIDString()
          @openContextMenuAtPointer morph
      until morph[expectedClick]
        morph = morph.parent
        if not morph?
          break
      if morph?
        if morph == @mouseDownMorph
          morph[expectedClick] @bounds.origin
    @mouseButton = null

  processDoubleClick: ->
    morph = @topMorphUnderPointer()
    @destroyTemporaries()
    if @children.length isnt 0
      @drop()
    else
      morph = morph.parent  while morph and not morph.mouseDoubleClick
      morph.mouseDoubleClick @bounds.origin  if morph
    @mouseButton = null
  
  processMouseScroll: (event) ->
    morph = @topMorphUnderPointer()
    morph = morph.parent  while morph and not morph.mouseScroll

    morph.mouseScroll (event.detail / -3) or ((if Object.prototype.hasOwnProperty.call(event,'wheelDeltaY') then event.wheelDeltaY / 120 else event.wheelDelta / 120)), event.wheelDeltaX / 120 or 0  if morph
  
  
  #
  #	drop event:
  #
  #        droppedImage
  #        droppedSVG
  #        droppedAudio
  #        droppedText
  #
  processDrop: (event) ->
    #
    #    find out whether an external image or audio file was dropped
    #    onto the world canvas, turn it into an offscreen canvas or audio
    #    element and dispatch the
    #    
    #        droppedImage(canvas, name)
    #        droppedSVG(image, name)
    #        droppedAudio(audio, name)
    #    
    #    events to interested Morphs at the mouse pointer
    #    if none of the above content types can be determined, the file contents
    #    is dispatched as an ArrayBuffer to interested Morphs:
    #
    #    ```droppedBinary(anArrayBuffer, name)```

    files = (if event instanceof FileList then event else (event.target.files || event.dataTransfer.files))
    url = (if event.dataTransfer then event.dataTransfer.getData("URL") else null)
    txt = (if event.dataTransfer then event.dataTransfer.getData("Text/HTML") else null)
    targetDrop = @topMorphUnderPointer()
    img = new Image()

    readSVG = (aFile) ->
      pic = new Image()
      frd = new FileReader()
      target = target.parent  until target.droppedSVG
      pic.onload = ->
        target.droppedSVG pic, aFile.name
      frd = new FileReader()
      frd.onloadend = (e) ->
        pic.src = e.target.result
      frd.readAsDataURL aFile

    readImage = (aFile) ->
      pic = new Image()
      frd = new FileReader()
      targetDrop = targetDrop.parent  until targetDrop.droppedImage
      pic.onload = ->
        canvas = newCanvas(new Point(pic.width, pic.height))
        canvas.getContext("2d").drawImage pic, 0, 0
        targetDrop.droppedImage canvas, aFile.name
      #
      frd = new FileReader()
      frd.onloadend = (e) ->
        pic.src = e.target.result
      #
      frd.readAsDataURL aFile
    #
    readAudio = (aFile) ->
      snd = new Audio()
      frd = new FileReader()
      targetDrop = targetDrop.parent  until targetDrop.droppedAudio
      frd.onloadend = (e) ->
        snd.src = e.target.result
        targetDrop.droppedAudio snd, aFile.name
      frd.readAsDataURL aFile
    
    readText = (aFile) ->
      frd = new FileReader()
      targetDrop = targetDrop.parent  until targetDrop.droppedText
      frd.onloadend = (e) ->
        targetDrop.droppedText e.target.result, aFile.name
      frd.readAsText aFile


    readBinary = (aFile) ->
      frd = new FileReader()
      targetDrop = targetDrop.parent  until targetDrop.droppedBinary
      frd.onloadend = (e) ->
        targetDrop.droppedBinary e.target.result, aFile.name
      frd.readAsArrayBuffer aFile

    parseImgURL = (html) ->
      url = ""
      start = html.indexOf("<img src=\"")
      return null  if start is -1
      start += 10
      for i in [start...html.length]
        c = html[i]
        return url  if c is "\""
        url = url.concat(c)
      null
    
    if files.length
      for file in files
        if file.type.indexOf("svg") != -1 && !WorldMorph.preferencesAndSettings.rasterizeSVGs
          readSVG file
        else if file.type.indexOf("image") is 0
          readImage file
        else if file.type.indexOf("audio") is 0
          readAudio file
        else if file.type.indexOf("text") is 0
          readText file
        else
          readBinary file
    else if url
      if contains(["gif", "png", "jpg", "jpeg", "bmp"], url.slice(url.lastIndexOf(".") + 1).toLowerCase())
        target = target.parent  until target.droppedImage
        img = new Image()
        img.onload = ->
          canvas = newCanvas(new Point(img.width, img.height))
          canvas.getContext("2d").drawImage img, 0, 0
          target.droppedImage canvas
        img.src = url
    else if txt
      targetDrop = targetDrop.parent  until targetDrop.droppedImage
      img = new Image()
      img.onload = ->
        canvas = newCanvas(new Point(img.width, img.height))
        canvas.getContext("2d").drawImage img, 0, 0
        targetDrop.droppedImage canvas
      src = parseImgURL(txt)
      img.src = src  if src
  
  
  # HandMorph tools
  destroyTemporaries: ->
    #
    #	temporaries are just an array of morphs which will be deleted upon
    #	the next mouse click, or whenever another temporary Morph decides
    #	that it needs to remove them. The primary purpose of temporaries is
    #	to display tools tips of speech bubble help.
    #
    @temporaries.forEach (morph) =>
      unless morph.isClickable and morph.bounds.containsPoint(@position())
        morph = morph.destroy()
        @temporaries.splice @temporaries.indexOf(morph), 1
  
  
  # HandMorph dragging optimization
  moveBy: (delta) ->
    Morph::trackChanges = false
    super delta
    Morph::trackChanges = true
    @fullChanged()

  processMouseMove: (pageX, pageY) ->    
    #startProcessMouseMove = new Date().getTime()
    posInDocument = getDocumentPositionOf(@world.worldCanvas)
    pos = new Point(pageX - posInDocument.x, pageY - posInDocument.y)
    @setPosition pos

    # determine the new mouse-over-list.
    # Spacial multiplexing
    # (search "multiplexing" for the other parts of
    # code where this matters)
    # There are two interpretations of what this
    # list should be:
    #   1) all morphs "pierced through" by the pointer
    #   2) all morphs parents of the topmost morph under the pointer
    # 2 is what is used in Cuis
    
    # commented-out implementation of 1):
    # mouseOverNew = @allMorphsAtPointer().reverse()
    mouseOverNew = @topMorphUnderPointer().allParentsTopToBottom()

    if (!@children.length) and (@mouseButton is "left")
      topMorph = @topMorphUnderPointer()
      morph = topMorph.rootForGrab()
      topMorph.mouseMove pos  if topMorph.mouseMove
      #
      # if a morph is marked for grabbing, just grab it
      if @morphToGrab
        if @morphToGrab.isDraggable
          morph = @morphToGrab
          @grab morph
        else if @morphToGrab.isTemplate
          morph = @morphToGrab.fullCopy()
          morph.isTemplate = false
          morph.isDraggable = true
          @grab morph
          @grabOrigin = @morphToGrab.situation()
        #
        # if the mouse has left its boundsIncludingChildren, center it
        if morph
          fb = morph.boundsIncludingChildren()
          unless fb.containsPoint(pos)
            @bounds.origin = fb.center()
            @grab morph
            @setPosition pos
    #endProcessMouseMove = new Date().getTime()
    #timeProcessMouseMove = endProcessMouseMove - startProcessMouseMove;
    #console.log('Execution time ProcessMouseMove: ' + timeProcessMouseMove);
    
    #
    #	original, more cautious code for grabbing Morphs,
    #	retained in case of needing to fall back:
    #
    #		if (morph === this.morphToGrab) {
    #			if (morph.isDraggable) {
    #				this.grab(morph);
    #			} else if (morph.isTemplate) {
    #				morph = morph.fullCopy();
    #				morph.isTemplate = false;
    #				morph.isDraggable = true;
    #				this.grab(morph);
    #			}
    #		}
    #
    @mouseOverList.forEach (old) =>
      unless contains(mouseOverNew, old)
        old.mouseLeave()  if old.mouseLeave
        old.mouseLeaveDragging()  if old.mouseLeaveDragging and @mouseButton
    #
    mouseOverNew.forEach (newMorph) =>
      unless contains(@mouseOverList, newMorph)
        newMorph.mouseEnter()  if newMorph.mouseEnter
        newMorph.mouseEnterDragging()  if newMorph.mouseEnterDragging and @mouseButton
      #
      # autoScrolling support:
      if @children.length
          if newMorph instanceof ScrollFrameMorph
              if !newMorph.bounds.insetBy(
                WorldMorph.preferencesAndSettings.scrollBarSize * 3
                ).containsPoint(@bounds.origin)
                  newMorph.startAutoScrolling();
    #
    @mouseOverList = mouseOverNew

  @coffeeScriptSourceOfThisClass: '''
# HandMorph ///////////////////////////////////////////////////////////

# The mouse cursor. Note that it's not a child of the WorldMorph, this Morph
# is never added to any other morph. [TODO] Find out why and write explanation.
# Not to be confused with the HandleMorph

class HandMorph extends Morph

  world: null
  mouseButton: null
  # used for example to check that
  # mouseDown and mouseUp happen on the
  # same Morph (otherwise clicks happen for
  # example when resizing a button via the
  # handle)
  mouseDownMorph: null
  morphToGrab: null
  grabOrigin: null
  mouseOverList: null
  temporaries: null
  touchHoldTimeout: null

  constructor: (@world) ->
    @mouseOverList = []
    @temporaries = []
    super()
    @bounds = new Rectangle()
  
  changed: ->
    if @world?
      b = @boundsIncludingChildren()
      if !b.extent().eq(new Point())
        @world.broken.push @boundsIncludingChildren().spread()
  
  
  # HandMorph navigation:
  topMorphUnderPointer: ->
    result = @world.topMorphSuchThat (m) =>
      m.visibleBounds().containsPoint(@bounds.origin) and
        !m.isMinimised and m.isVisible and (m.noticesTransparentClick or
        (not m.isTransparentAt(@bounds.origin))) and (m not instanceof ShadowMorph)
    if result?
      return result
    else
      return @world

  menuAtPointer: ->
    result = @world.topMorphSuchThat (m) =>
      m.visibleBounds().containsPoint(@bounds.origin) and
        !m.isMinimised and m.isVisible and (m.noticesTransparentClick or
        (not m.isTransparentAt(@bounds.origin))) and (m instanceof MenuMorph)
    return result

  leftOrRightClickOnMenuItemWithText: (whichMouseButtonPressed, textLabelOfClickedItem, textLabelOccurrenceNumber) ->
    itemToTrigger = @world.activeMenu.nthChildSuchThat textLabelOccurrenceNumber, (m) ->
      m.labelString == textLabelOfClickedItem

    # these three are checks and actions that normally
    # would happen on MouseDown event, but we
    # removed that event as we collapsed the down and up
    # into this colasesced higher-level event,
    # but we still need to make these checks and actions
    @destroyActiveMenuIfHandHasNotActionedIt itemToTrigger
    @destroyActiveHandleIfHandHasNotActionedIt itemToTrigger
    @stopEditingIfActionIsElsewhere itemToTrigger

    if whichMouseButtonPressed == "left"
      itemToTrigger.mouseClickLeft()
    else if whichMouseButtonPressed == "right"
      @openContextMenuAtPointer itemToTrigger.children[0]


  openContextMenuAtPointer: (morphTheMenuIsAbout) ->
    # note that the morphs that the menu
    # belongs to might not be under the mouse.
    # It usually is, but in cases
    # where a system test is playing against
    # a world setup that has varied since the
    # recording, this could be the case.

    # these three are checks and actions that normally
    # would happen on MouseDown event, but we
    # removed that event as we collapsed the down and up
    # into this colasesced higher-level event,
    # but we still need to make these checks and actions
    @destroyActiveMenuIfHandHasNotActionedIt morphTheMenuIsAbout
    @destroyActiveHandleIfHandHasNotActionedIt morphTheMenuIsAbout
    @stopEditingIfActionIsElsewhere morphTheMenuIsAbout

    contextMenu = morphTheMenuIsAbout.contextMenu()
    while (not contextMenu) and morphTheMenuIsAbout.parent
      morphTheMenuIsAbout = morphTheMenuIsAbout.parent
      contextMenu = morphTheMenuIsAbout.contextMenu()

    if contextMenu 
      contextMenu.popUpAtHand() 

  #
  #    alternative -  more elegant and possibly more
  #	performant - solution for topMorphUnderPointer.
  #	Has some issues, commented out for now
  #
  #HandMorph.prototype.topMorphUnderPointer = function () {
  #	var myself = this;
  #	return this.world.topMorphSuchThat(function (m) {
  #		return m.visibleBounds().containsPoint(myself.bounds.origin) &&
  #			!m.isMinimised &&
  #     m.isVisible &&
  #			(m.noticesTransparentClick ||
  #				(! m.isTransparentAt(myself.bounds.origin))) &&
  #			(! (m instanceof ShadowMorph));
  #	});
  #};
  #


  # not used in ZK yet
  allMorphsAtPointer: ->
    return @world.collectAllChildrenBottomToTopSuchThat (m) =>
      !m.isMinimised and m.isVisible and m.visibleBounds().containsPoint(@bounds.origin)
  
  
  
  # HandMorph dragging and dropping:
  #
  #	drag 'n' drop events, method(arg) -> receiver:
  #
  #		prepareToBeGrabbed(handMorph) -> grabTarget
  #		reactToGrabOf(grabbedMorph) -> oldParent
  #		wantsDropOf(morphToDrop) ->  newParent
  #		justDropped(handMorph) -> droppedMorph
  #		reactToDropOf(droppedMorph, handMorph) -> newParent
  #
  dropTargetFor: (aMorph) ->
    target = @topMorphUnderPointer()
    target = target.parent  until target.wantsDropOf(aMorph)
    target
  
  grab: (aMorph) ->
    oldParent = aMorph.parent
    return null  if aMorph instanceof WorldMorph
    if !@children.length
      @world.stopEditing()
      @grabOrigin = aMorph.situation()
      aMorph.prepareToBeGrabbed @  if aMorph.prepareToBeGrabbed
      @add aMorph
      # you must add the shadow
      # after the morph has been added
      # because "@add aMorph" causes
      # the morph to be painted potentially
      # for the first time.
      # The shadow needs the image of the
      # morph to make the shadow, so
      # this is why we add the shadow after
      # the morph has been added.
      aMorph.addShadow()
      @changed()
      oldParent.reactToGrabOf aMorph  if oldParent and oldParent.reactToGrabOf
  
  drop: ->
    if @children.length
      morphToDrop = @children[0]
      target = @dropTargetFor(morphToDrop)
      @changed()
      target.add morphToDrop
      morphToDrop.changed()
      morphToDrop.removeShadow()
      @children = []
      @setExtent new Point()
      morphToDrop.justDropped @  if morphToDrop.justDropped
      target.reactToDropOf morphToDrop, @  if target.reactToDropOf
      @dragOrigin = null
  
  # HandMorph event dispatching:
  #
  #    mouse events:
  #
  #		mouseDownLeft
  #		mouseDownRight
  #		mouseClickLeft
  #		mouseClickRight
  #   mouseDoubleClick
  #		mouseEnter
  #		mouseLeave
  #		mouseEnterDragging
  #		mouseLeaveDragging
  #		mouseMove
  #		mouseScroll
  #
  # Note that some handlers don't want the event but the
  # interesting parameters of the event. This is because
  # the testing harness only stores the interesting parameters
  # rather than a multifaceted and sometimes browser-specific
  # event object.

  destroyActiveHandleIfHandHasNotActionedIt: (actionedMorph) ->
    if @world.activeHandle?
      if actionedMorph isnt @world.activeHandle
        @world.activeHandle = @world.activeHandle.destroy()    

  destroyActiveMenuIfHandHasNotActionedIt: (actionedMorph) ->
    if @world.activeMenu?
      unless @world.activeMenu.containedInParentsOf(actionedMorph)
        # if there is a menu open and the user clicked on
        # something that is not part of the menu then
        # destroy the menu 
        @world.activeMenu = @world.activeMenu.destroy()
      else
        clearInterval @touchHoldTimeout

  stopEditingIfActionIsElsewhere: (actionedMorph) ->
    if @world.caret?
      # there is a caret on the screen
      # depending on what the user is clicking on,
      # we might need to close an ongoing edit
      # operation, which means deleting the
      # caret and un-selecting anything that was selected.
      # Note that we don't want to interrupt an edit
      # if the user is invoking/clicking on anything
      # inside a menu, because the invoked function
      # might do something with the selection
      # (for example doSelection takes the current selection).
      if actionedMorph isnt @world.caret.target
        # user clicked on something other than what the
        # caret is attached to
        if @world.activeMenu?
          unless @world.activeMenu.containedInParentsOf(actionedMorph)
            # only dismiss editing if the actionedMorph the user
            # clicked on is not part of a menu.
            @world.stopEditing()
        # there is no menu at all, in which case
        # we know there was an editing operation going
        # on that we need to stop
        else
          @world.stopEditing()

  processMouseDown: (button, ctrlKey) ->
    @destroyTemporaries()
    @morphToGrab = null
    # check whether we are in the middle
    # of a drag/drop operation
    if @children.length
      @drop()
      @mouseButton = null
    else
      morph = @topMorphUnderPointer()
      @destroyActiveMenuIfHandHasNotActionedIt morph
      @destroyActiveHandleIfHandHasNotActionedIt morph
      @stopEditingIfActionIsElsewhere morph

      @morphToGrab = morph.rootForGrab()  unless morph.mouseMove
      if button is 2 or ctrlKey
        @mouseButton = "right"
        actualClick = "mouseDownRight"
        expectedClick = "mouseClickRight"
      else
        @mouseButton = "left"
        actualClick = "mouseDownLeft"
        expectedClick = "mouseClickLeft"

      @mouseDownMorph = morph
      @mouseDownMorph = @mouseDownMorph.parent  until @mouseDownMorph[expectedClick]
      morph = morph.parent  until morph[actualClick]
      morph[actualClick] @bounds.origin
  
  # touch events, see:
  # https://developer.apple.com/library/safari/documentation/appleapplications/reference/safariwebcontent/HandlingEvents/HandlingEvents.html
  # A long touch emulates a right click. This is done via
  # setting a timer 400ms after the touch which triggers
  # a right mouse click. Any touch event before then just
  # resets the timer, so one has to hold the finger in
  # position for the right click to happen.
  processTouchStart: (event) ->
    event.preventDefault()
    WorldMorph.preferencesAndSettings.isTouchDevice = true
    clearInterval @touchHoldTimeout
    if event.touches.length is 1
      # simulate mouseRightClick
      @touchHoldTimeout = setInterval(=>
        @processMouseDown 2 # button 2 is the right one
        @processMouseUp 2 # button 2 is the right one, we don't use this parameter
        event.preventDefault() # I don't think that this is needed
        clearInterval @touchHoldTimeout
      , 400)
      @processMouseMove event.touches[0].pageX, event.touches[0].pageY # update my position
      @processMouseDown 0 # button zero is the left button
  
  processTouchMove: (event) ->
    # Prevent scrolling on this element
    event.preventDefault()

    if event.touches.length is 1
      touch = event.touches[0]
      @processMouseMove touch.pageX, touch.pageY
      clearInterval @touchHoldTimeout
  
  processTouchEnd: (event) ->
    # note that the mouse down event handler
    # that is calling this method has ALREADY
    # added a mousdown command

    WorldMorph.preferencesAndSettings.isTouchDevice = true
    clearInterval @touchHoldTimeout
    @processMouseUp 0 # button zero is the left button, we don't use this parameter
  
   # note that the button param is not used,
   # but adding it for consistency...
   processMouseUp: (button) ->
    morph = @topMorphUnderPointer()
    alreadyRecordedLeftOrRightClickOnMenuItem = false
    @destroyTemporaries()
    if @children.length
      @drop()
    else
      # let's check if the user clicked on a menu item,
      # in which case we add a special dedicated command
      # [TODO] you need to do some of this only if you
      # are recording a test, it's worth saving
      # these steps...
      menuItemMorph = morph.parentThatIsA(MenuItemMorph)
      if menuItemMorph
        # we check whether the menuitem is actually part
        # of an activeMenu. Keep in mind you could have
        # detached a menuItem and placed it on any other
        # morph so you need to ascertain that you'll
        # find it in the activeMenu later on...
        if @world.activeMenu == menuItemMorph.parent
          labelString = menuItemMorph.labelString
          morphSpawningTheMenu = menuItemMorph.parent.parent
          occurrenceNumber = menuItemMorph.howManySiblingsBeforeMeSuchThat (m) ->
            m.labelString == labelString
          # this method below is also going to remove
          # the mouse down/up commands that have
          # recently/jsut been added.
          @world.systemTestsRecorderAndPlayer.addCommandLeftOrRightClickOnMenuItem(@mouseButton, labelString, occurrenceNumber + 1)
          alreadyRecordedLeftOrRightClickOnMenuItem = true
      if @mouseButton is "left"
        expectedClick = "mouseClickLeft"
      else
        expectedClick = "mouseClickRight"
        if @mouseButton
          if !alreadyRecordedLeftOrRightClickOnMenuItem
            # this being a right click, pop
            # up a menu as needed.
            @world.systemTestsRecorderAndPlayer.addOpenContextMenuCommand morph.uniqueIDString()
          @openContextMenuAtPointer morph
      until morph[expectedClick]
        morph = morph.parent
        if not morph?
          break
      if morph?
        if morph == @mouseDownMorph
          morph[expectedClick] @bounds.origin
    @mouseButton = null

  processDoubleClick: ->
    morph = @topMorphUnderPointer()
    @destroyTemporaries()
    if @children.length isnt 0
      @drop()
    else
      morph = morph.parent  while morph and not morph.mouseDoubleClick
      morph.mouseDoubleClick @bounds.origin  if morph
    @mouseButton = null
  
  processMouseScroll: (event) ->
    morph = @topMorphUnderPointer()
    morph = morph.parent  while morph and not morph.mouseScroll

    morph.mouseScroll (event.detail / -3) or ((if Object.prototype.hasOwnProperty.call(event,'wheelDeltaY') then event.wheelDeltaY / 120 else event.wheelDelta / 120)), event.wheelDeltaX / 120 or 0  if morph
  
  
  #
  #	drop event:
  #
  #        droppedImage
  #        droppedSVG
  #        droppedAudio
  #        droppedText
  #
  processDrop: (event) ->
    #
    #    find out whether an external image or audio file was dropped
    #    onto the world canvas, turn it into an offscreen canvas or audio
    #    element and dispatch the
    #    
    #        droppedImage(canvas, name)
    #        droppedSVG(image, name)
    #        droppedAudio(audio, name)
    #    
    #    events to interested Morphs at the mouse pointer
    #    if none of the above content types can be determined, the file contents
    #    is dispatched as an ArrayBuffer to interested Morphs:
    #
    #    ```droppedBinary(anArrayBuffer, name)```

    files = (if event instanceof FileList then event else (event.target.files || event.dataTransfer.files))
    url = (if event.dataTransfer then event.dataTransfer.getData("URL") else null)
    txt = (if event.dataTransfer then event.dataTransfer.getData("Text/HTML") else null)
    targetDrop = @topMorphUnderPointer()
    img = new Image()

    readSVG = (aFile) ->
      pic = new Image()
      frd = new FileReader()
      target = target.parent  until target.droppedSVG
      pic.onload = ->
        target.droppedSVG pic, aFile.name
      frd = new FileReader()
      frd.onloadend = (e) ->
        pic.src = e.target.result
      frd.readAsDataURL aFile

    readImage = (aFile) ->
      pic = new Image()
      frd = new FileReader()
      targetDrop = targetDrop.parent  until targetDrop.droppedImage
      pic.onload = ->
        canvas = newCanvas(new Point(pic.width, pic.height))
        canvas.getContext("2d").drawImage pic, 0, 0
        targetDrop.droppedImage canvas, aFile.name
      #
      frd = new FileReader()
      frd.onloadend = (e) ->
        pic.src = e.target.result
      #
      frd.readAsDataURL aFile
    #
    readAudio = (aFile) ->
      snd = new Audio()
      frd = new FileReader()
      targetDrop = targetDrop.parent  until targetDrop.droppedAudio
      frd.onloadend = (e) ->
        snd.src = e.target.result
        targetDrop.droppedAudio snd, aFile.name
      frd.readAsDataURL aFile
    
    readText = (aFile) ->
      frd = new FileReader()
      targetDrop = targetDrop.parent  until targetDrop.droppedText
      frd.onloadend = (e) ->
        targetDrop.droppedText e.target.result, aFile.name
      frd.readAsText aFile


    readBinary = (aFile) ->
      frd = new FileReader()
      targetDrop = targetDrop.parent  until targetDrop.droppedBinary
      frd.onloadend = (e) ->
        targetDrop.droppedBinary e.target.result, aFile.name
      frd.readAsArrayBuffer aFile

    parseImgURL = (html) ->
      url = ""
      start = html.indexOf("<img src=\"")
      return null  if start is -1
      start += 10
      for i in [start...html.length]
        c = html[i]
        return url  if c is "\""
        url = url.concat(c)
      null
    
    if files.length
      for file in files
        if file.type.indexOf("svg") != -1 && !WorldMorph.preferencesAndSettings.rasterizeSVGs
          readSVG file
        else if file.type.indexOf("image") is 0
          readImage file
        else if file.type.indexOf("audio") is 0
          readAudio file
        else if file.type.indexOf("text") is 0
          readText file
        else
          readBinary file
    else if url
      if contains(["gif", "png", "jpg", "jpeg", "bmp"], url.slice(url.lastIndexOf(".") + 1).toLowerCase())
        target = target.parent  until target.droppedImage
        img = new Image()
        img.onload = ->
          canvas = newCanvas(new Point(img.width, img.height))
          canvas.getContext("2d").drawImage img, 0, 0
          target.droppedImage canvas
        img.src = url
    else if txt
      targetDrop = targetDrop.parent  until targetDrop.droppedImage
      img = new Image()
      img.onload = ->
        canvas = newCanvas(new Point(img.width, img.height))
        canvas.getContext("2d").drawImage img, 0, 0
        targetDrop.droppedImage canvas
      src = parseImgURL(txt)
      img.src = src  if src
  
  
  # HandMorph tools
  destroyTemporaries: ->
    #
    #	temporaries are just an array of morphs which will be deleted upon
    #	the next mouse click, or whenever another temporary Morph decides
    #	that it needs to remove them. The primary purpose of temporaries is
    #	to display tools tips of speech bubble help.
    #
    @temporaries.forEach (morph) =>
      unless morph.isClickable and morph.bounds.containsPoint(@position())
        morph = morph.destroy()
        @temporaries.splice @temporaries.indexOf(morph), 1
  
  
  # HandMorph dragging optimization
  moveBy: (delta) ->
    Morph::trackChanges = false
    super delta
    Morph::trackChanges = true
    @fullChanged()

  processMouseMove: (pageX, pageY) ->    
    #startProcessMouseMove = new Date().getTime()
    posInDocument = getDocumentPositionOf(@world.worldCanvas)
    pos = new Point(pageX - posInDocument.x, pageY - posInDocument.y)
    @setPosition pos

    # determine the new mouse-over-list.
    # Spacial multiplexing
    # (search "multiplexing" for the other parts of
    # code where this matters)
    # There are two interpretations of what this
    # list should be:
    #   1) all morphs "pierced through" by the pointer
    #   2) all morphs parents of the topmost morph under the pointer
    # 2 is what is used in Cuis
    
    # commented-out implementation of 1):
    # mouseOverNew = @allMorphsAtPointer().reverse()
    mouseOverNew = @topMorphUnderPointer().allParentsTopToBottom()

    if (!@children.length) and (@mouseButton is "left")
      topMorph = @topMorphUnderPointer()
      morph = topMorph.rootForGrab()
      topMorph.mouseMove pos  if topMorph.mouseMove
      #
      # if a morph is marked for grabbing, just grab it
      if @morphToGrab
        if @morphToGrab.isDraggable
          morph = @morphToGrab
          @grab morph
        else if @morphToGrab.isTemplate
          morph = @morphToGrab.fullCopy()
          morph.isTemplate = false
          morph.isDraggable = true
          @grab morph
          @grabOrigin = @morphToGrab.situation()
        #
        # if the mouse has left its boundsIncludingChildren, center it
        if morph
          fb = morph.boundsIncludingChildren()
          unless fb.containsPoint(pos)
            @bounds.origin = fb.center()
            @grab morph
            @setPosition pos
    #endProcessMouseMove = new Date().getTime()
    #timeProcessMouseMove = endProcessMouseMove - startProcessMouseMove;
    #console.log('Execution time ProcessMouseMove: ' + timeProcessMouseMove);
    
    #
    #	original, more cautious code for grabbing Morphs,
    #	retained in case of needing to fall back:
    #
    #		if (morph === this.morphToGrab) {
    #			if (morph.isDraggable) {
    #				this.grab(morph);
    #			} else if (morph.isTemplate) {
    #				morph = morph.fullCopy();
    #				morph.isTemplate = false;
    #				morph.isDraggable = true;
    #				this.grab(morph);
    #			}
    #		}
    #
    @mouseOverList.forEach (old) =>
      unless contains(mouseOverNew, old)
        old.mouseLeave()  if old.mouseLeave
        old.mouseLeaveDragging()  if old.mouseLeaveDragging and @mouseButton
    #
    mouseOverNew.forEach (newMorph) =>
      unless contains(@mouseOverList, newMorph)
        newMorph.mouseEnter()  if newMorph.mouseEnter
        newMorph.mouseEnterDragging()  if newMorph.mouseEnterDragging and @mouseButton
      #
      # autoScrolling support:
      if @children.length
          if newMorph instanceof ScrollFrameMorph
              if !newMorph.bounds.insetBy(
                WorldMorph.preferencesAndSettings.scrollBarSize * 3
                ).containsPoint(@bounds.origin)
                  newMorph.startAutoScrolling();
    #
    @mouseOverList = mouseOverNew
  '''

# HandleMorph ////////////////////////////////////////////////////////
# not to be confused with the HandMorph
# I am a resize / move handle that can be attached to any Morph

# this comment below is needed to figure our dependencies between classes
# REQUIRES globalFunctions

class HandleMorph extends Morph

  target: null
  minExtent: null
  inset: null
  type: null # "resize" or "move"
  step: null

  constructor: (@target = null, minX = 0, minY = 0, insetX, insetY, @type = "resize") ->
    # if insetY is missing, it will be the same as insetX
    @minExtent = new Point(minX, minY)
    @inset = new Point(insetX or 0, insetY or insetX or 0)
    super()
    @color = new Color(255, 255, 255)
    @noticesTransparentClick = true
    size = WorldMorph.preferencesAndSettings.handleSize
    @silentSetExtent new Point(size, size)
    if @target
      @target.add @
    @updatePosition()

  updatePosition: ->
    if @target
        @setPosition @target.bottomRight().subtract(@extent().add(@inset))
        # todo wow, wasteful!
        @target.changed()
  
  
  # HandleMorph drawing:
  updateRendering: ->
    @normalImage = newCanvas(@extent().scaleBy pixelRatio)
    normalImageContext = @normalImage.getContext("2d")
    normalImageContext.scale pixelRatio, pixelRatio
    @highlightImage = newCanvas(@extent().scaleBy pixelRatio)
    highlightImageContext = @highlightImage.getContext("2d")
    highlightImageContext.scale pixelRatio, pixelRatio
    @handleMorphRenderingHelper normalImageContext, @color, new Color(100, 100, 100)
    @handleMorphRenderingHelper highlightImageContext, new Color(100, 100, 255), new Color(255, 255, 255)
    @image = @normalImage
  
  handleMorphRenderingHelper: (context, color, shadowColor) ->
    context.lineWidth = 1
    context.lineCap = "round"
    context.strokeStyle = color.toString()
    if @type is "move"
      p1 = @bottomLeft().subtract(@position())
      p11 = p1.copy()
      p2 = @topRight().subtract(@position())
      p22 = p2.copy()
      for i in [0..@height()] by 6
        p11.y = p1.y - i
        p22.y = p2.y - i
        context.beginPath()
        context.moveTo p11.x, p11.y
        context.lineTo p22.x, p22.y
        context.closePath()
        context.stroke()

    p1 = @bottomLeft().subtract(@position())
    p11 = p1.copy()
    p2 = @topRight().subtract(@position())
    p22 = p2.copy()
    for i in [0..@width()] by 6
      p11.x = p1.x + i
      p22.x = p2.x + i
      context.beginPath()
      context.moveTo p11.x, p11.y
      context.lineTo p22.x, p22.y
      context.closePath()
      context.stroke()

    context.strokeStyle = shadowColor.toString()
    if @type is "move"
      p1 = @bottomLeft().subtract(@position())
      p11 = p1.copy()
      p2 = @topRight().subtract(@position())
      p22 = p2.copy()
      for i in [-1..@height()] by 6
        p11.y = p1.y - i
        p22.y = p2.y - i
        context.beginPath()
        context.moveTo p11.x, p11.y
        context.lineTo p22.x, p22.y
        context.closePath()
        context.stroke()

    p1 = @bottomLeft().subtract(@position())
    p11 = p1.copy()
    p2 = @topRight().subtract(@position())
    p22 = p2.copy()
    for i in [2..@width()] by 6
      p11.x = p1.x + i
      p22.x = p2.x + i
      context.beginPath()
      context.moveTo p11.x, p11.y
      context.lineTo p22.x, p22.y
      context.closePath()
      context.stroke()
  

  # implement dummy methods in here
  # so the handle catches the clicks and
  # prevents the parent to do anything.
  mouseClickLeft: ->
  mouseUpLeft: ->
  mouseDownLeft: ->
  
  # HandleMorph stepping:
  mouseDownLeft: (pos) ->
    world = @root()
    offset = pos.subtract(@bounds.origin)
    return null  unless @target
    @step = =>
      if world.hand.mouseButton
        newPos = world.hand.bounds.origin.copy().subtract(offset)
        if @type is "resize"
          newExt = newPos.add(@extent().add(@inset)).subtract(@target.bounds.origin)
          newExt = newExt.max(@minExtent)
          @target.setExtent newExt
          @setPosition @target.bottomRight().subtract(@extent().add(@inset))
          # not all morphs provide a layoutSubmorphs, so check
          if @target.layoutSubmorphs?
            @target.layoutSubmorphs()
        else # type === 'move'
          @target.setPosition newPos.subtract(@target.extent()).add(@extent())
      else
        @step = null
    
    unless @target.step
      @target.step = noOperation
  
  
  # HandleMorph dragging and dropping:
  rootForGrab: ->
    @
  
  
  # HandleMorph events:
  mouseEnter: ->
    @image = @highlightImage
    @changed()
  
  mouseLeave: ->
    @image = @normalImage
    @changed()
  
    
  # HandleMorph menu:
  attach: ->
    # get rid of any previous temporary
    # active menu because it's meant to be
    # out of view anyways, otherwise we show
    # its submorphs in the "attach to..." options
    # which is most probably not wanted.
    if world.activeMenu
      world.activeMenu = world.activeMenu.destroy()
    choices = world.plausibleTargetAndDestinationMorphs(@)
    menu = new MenuMorph(@, "choose target:")
    if choices.length > 0
      choices.forEach (each) =>
        menu.addItem each.toString().slice(0, 50), ->
          @isDraggable = false
          @target = each
          @updateRendering()
          @noticesTransparentClick = true
    else
      # the ideal would be to not show the
      # "attach" menu entry at all but for the
      # time being it's quite costly to
      # find the eligible morphs to attach
      # to, so for now let's just calculate
      # this list if the user invokes the
      # command, and if there are no good
      # morphs then show some kind of message.
      menu = new MenuMorph(@, "no morphs to attach to")
    menu.popUpAtHand()  if choices.length

  @coffeeScriptSourceOfThisClass: '''
# HandleMorph ////////////////////////////////////////////////////////
# not to be confused with the HandMorph
# I am a resize / move handle that can be attached to any Morph

# this comment below is needed to figure our dependencies between classes
# REQUIRES globalFunctions

class HandleMorph extends Morph

  target: null
  minExtent: null
  inset: null
  type: null # "resize" or "move"
  step: null

  constructor: (@target = null, minX = 0, minY = 0, insetX, insetY, @type = "resize") ->
    # if insetY is missing, it will be the same as insetX
    @minExtent = new Point(minX, minY)
    @inset = new Point(insetX or 0, insetY or insetX or 0)
    super()
    @color = new Color(255, 255, 255)
    @noticesTransparentClick = true
    size = WorldMorph.preferencesAndSettings.handleSize
    @silentSetExtent new Point(size, size)
    if @target
      @target.add @
    @updatePosition()

  updatePosition: ->
    if @target
        @setPosition @target.bottomRight().subtract(@extent().add(@inset))
        # todo wow, wasteful!
        @target.changed()
  
  
  # HandleMorph drawing:
  updateRendering: ->
    @normalImage = newCanvas(@extent().scaleBy pixelRatio)
    normalImageContext = @normalImage.getContext("2d")
    normalImageContext.scale pixelRatio, pixelRatio
    @highlightImage = newCanvas(@extent().scaleBy pixelRatio)
    highlightImageContext = @highlightImage.getContext("2d")
    highlightImageContext.scale pixelRatio, pixelRatio
    @handleMorphRenderingHelper normalImageContext, @color, new Color(100, 100, 100)
    @handleMorphRenderingHelper highlightImageContext, new Color(100, 100, 255), new Color(255, 255, 255)
    @image = @normalImage
  
  handleMorphRenderingHelper: (context, color, shadowColor) ->
    context.lineWidth = 1
    context.lineCap = "round"
    context.strokeStyle = color.toString()
    if @type is "move"
      p1 = @bottomLeft().subtract(@position())
      p11 = p1.copy()
      p2 = @topRight().subtract(@position())
      p22 = p2.copy()
      for i in [0..@height()] by 6
        p11.y = p1.y - i
        p22.y = p2.y - i
        context.beginPath()
        context.moveTo p11.x, p11.y
        context.lineTo p22.x, p22.y
        context.closePath()
        context.stroke()

    p1 = @bottomLeft().subtract(@position())
    p11 = p1.copy()
    p2 = @topRight().subtract(@position())
    p22 = p2.copy()
    for i in [0..@width()] by 6
      p11.x = p1.x + i
      p22.x = p2.x + i
      context.beginPath()
      context.moveTo p11.x, p11.y
      context.lineTo p22.x, p22.y
      context.closePath()
      context.stroke()

    context.strokeStyle = shadowColor.toString()
    if @type is "move"
      p1 = @bottomLeft().subtract(@position())
      p11 = p1.copy()
      p2 = @topRight().subtract(@position())
      p22 = p2.copy()
      for i in [-1..@height()] by 6
        p11.y = p1.y - i
        p22.y = p2.y - i
        context.beginPath()
        context.moveTo p11.x, p11.y
        context.lineTo p22.x, p22.y
        context.closePath()
        context.stroke()

    p1 = @bottomLeft().subtract(@position())
    p11 = p1.copy()
    p2 = @topRight().subtract(@position())
    p22 = p2.copy()
    for i in [2..@width()] by 6
      p11.x = p1.x + i
      p22.x = p2.x + i
      context.beginPath()
      context.moveTo p11.x, p11.y
      context.lineTo p22.x, p22.y
      context.closePath()
      context.stroke()
  

  # implement dummy methods in here
  # so the handle catches the clicks and
  # prevents the parent to do anything.
  mouseClickLeft: ->
  mouseUpLeft: ->
  mouseDownLeft: ->
  
  # HandleMorph stepping:
  mouseDownLeft: (pos) ->
    world = @root()
    offset = pos.subtract(@bounds.origin)
    return null  unless @target
    @step = =>
      if world.hand.mouseButton
        newPos = world.hand.bounds.origin.copy().subtract(offset)
        if @type is "resize"
          newExt = newPos.add(@extent().add(@inset)).subtract(@target.bounds.origin)
          newExt = newExt.max(@minExtent)
          @target.setExtent newExt
          @setPosition @target.bottomRight().subtract(@extent().add(@inset))
          # not all morphs provide a layoutSubmorphs, so check
          if @target.layoutSubmorphs?
            @target.layoutSubmorphs()
        else # type === 'move'
          @target.setPosition newPos.subtract(@target.extent()).add(@extent())
      else
        @step = null
    
    unless @target.step
      @target.step = noOperation
  
  
  # HandleMorph dragging and dropping:
  rootForGrab: ->
    @
  
  
  # HandleMorph events:
  mouseEnter: ->
    @image = @highlightImage
    @changed()
  
  mouseLeave: ->
    @image = @normalImage
    @changed()
  
    
  # HandleMorph menu:
  attach: ->
    # get rid of any previous temporary
    # active menu because it's meant to be
    # out of view anyways, otherwise we show
    # its submorphs in the "attach to..." options
    # which is most probably not wanted.
    if world.activeMenu
      world.activeMenu = world.activeMenu.destroy()
    choices = world.plausibleTargetAndDestinationMorphs(@)
    menu = new MenuMorph(@, "choose target:")
    if choices.length > 0
      choices.forEach (each) =>
        menu.addItem each.toString().slice(0, 50), ->
          @isDraggable = false
          @target = each
          @updateRendering()
          @noticesTransparentClick = true
    else
      # the ideal would be to not show the
      # "attach" menu entry at all but for the
      # time being it's quite costly to
      # find the eligible morphs to attach
      # to, so for now let's just calculate
      # this list if the user invokes the
      # command, and if there are no good
      # morphs then show some kind of message.
      menu = new MenuMorph(@, "no morphs to attach to")
    menu.popUpAtHand()  if choices.length
  '''

# HashCalculator ///////////////////////////////////////////////////
# adapted from http://stackoverflow.com/a/7616484

# Currently used to differentiate the filenames
# for test reference images taken in
# different os/browser config: a hash of the
# configuration is added to the filename.

class HashCalculator

  @calculateHash: (theString) ->
      return hash  if theString.length is 0

      for i in [0...theString.length]
        chr = theString.charCodeAt(i)
        hash = ((hash << 5) - hash) + chr
        hash |= 0 # Convert to 32bit integer
        i++
      return hash

  @coffeeScriptSourceOfThisClass: '''
# HashCalculator ///////////////////////////////////////////////////
# adapted from http://stackoverflow.com/a/7616484

# Currently used to differentiate the filenames
# for test reference images taken in
# different os/browser config: a hash of the
# configuration is added to the filename.

class HashCalculator

  @calculateHash: (theString) ->
      return hash  if theString.length is 0

      for i in [0...theString.length]
        chr = theString.charCodeAt(i)
        hash = ((hash << 5) - hash) + chr
        hash |= 0 # Convert to 32bit integer
        i++
      return hash
  '''

# InspectorMorph //////////////////////////////////////////////////////

class InspectorMorph extends BoxMorph

  target: null
  currentProperty: null
  showing: "attributes"
  markOwnershipOfProperties: false
  # panes:
  label: null
  list: null
  detail: null
  work: null
  buttonInspect: null
  buttonClose: null
  buttonSubset: null
  buttonEdit: null
  resizer: null

  constructor: (@target) ->
    super()
    # override inherited properties:
    @silentSetExtent new Point(WorldMorph.preferencesAndSettings.handleSize * 20,
      WorldMorph.preferencesAndSettings.handleSize * 20 * 2 / 3)
    @isDraggable = true
    @border = 1
    @edge = if WorldMorph.preferencesAndSettings.isFlat then 1 else 5
    @color = new Color(60, 60, 60)
    @borderColor = new Color(95, 95, 95)
    @buildAndConnectChildren()  if @target
  
  setTarget: (target) ->
    @target = target
    @currentProperty = null
    @buildAndConnectChildren()
  
  buildAndConnectChildren: ->
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.alignmentOfMorphIDsMechanism
      world.alignIDsOfNextMorphsInSystemTests()
    attribs = []
    #
    # remove existing panes
    @destroyAll()

    #
    @children = []
    #
    # label
    @label = new TextMorph(@target.toString())
    @label.fontSize = WorldMorph.preferencesAndSettings.menuFontSize
    @label.isBold = true
    @label.color = new Color(255, 255, 255)
    @add @label
    
    # properties list. Note that this picks up ALL properties
    # (enumerable such as strings and un-enumerable such as functions)
    # of the whole prototype chain.
    #
    #   a) some of these are DECLARED as part of the class that defines the object
    #   and are proprietary to the object. These are shown RED
    # 
    #   b) some of these are proprietary to the object but are initialised by
    #   code higher in the prototype chain. These are shown GREEN
    #
    #   c) some of these are not proprietary, i.e. they belong to an object up
    #   the chain of prototypes. These are shown BLUE
    #
    # todo: show the static methods and variables in yet another color.
    
    for property of @target
      # dummy condition, to be refined
      attribs.push property  if property
    if @showing is "attributes"
      attribs = attribs.filter((prop) =>
        not isFunction @target[prop]
      )
    else if @showing is "methods"
      attribs = attribs.filter((prop) =>
        isFunction @target[prop]
      )
    # otherwise show all properties
    # label getter
    # format list
    # format element: [color, predicate(element]
    
    staticProperties = Object.getOwnPropertyNames(@target.constructor)
    # get rid of all the standar fuff properties that are in classes
    staticProperties = staticProperties.filter((prop) =>
        prop not in ["name","length","prototype","caller","__super__","arguments"]
    )
    if @showing is "attributes"
      staticFunctions = []
      staticAttributes = staticProperties.filter((prop) =>
        not isFunction(@target.constructor[prop])
      )
    else if @showing is "methods"
      staticFunctions = staticProperties.filter((prop) =>
        isFunction(@target.constructor[prop])
      )
      staticAttributes = []
    else
      staticFunctions = staticProperties.filter((prop) =>
        isFunction(@target.constructor[prop])
      )
      staticAttributes = staticProperties.filter((prop) =>
        prop not in staticFunctions
      )
    #alert "stat fun " + staticFunctions + " stat attr " + staticAttributes
    attribs = (attribs.concat staticFunctions).concat staticAttributes
    #alert " all attribs " + attribs
    
    # caches the own methods of the object
    if @markOwnershipOfProperties
      targetOwnMethods = Object.getOwnPropertyNames(@target.constructor.prototype)
      #alert targetOwnMethods

    doubleClickAction = =>
      if (!isObject(@currentProperty))
        return
      world = @world()
      inspector = @constructor @currentProperty
      inspector.setPosition world.hand.position()
      inspector.keepWithin world
      world.add inspector
      inspector.changed()

    @list = new ListMorph(@, InspectorMorph.prototype.selectionFromList, (if @target instanceof Array then attribs else attribs.sort()), null,(
      if @markOwnershipOfProperties
        [
          # give color criteria from the most general to the most specific
          [new Color(0, 0, 180),
            (element) =>
              # if the element is either an enumerable property of the object
              # or it belongs to the own methods, then it is highlighted.
              # Note that hasOwnProperty doesn't pick up non-enumerable properties such as
              # functions.
              # In theory, getOwnPropertyNames should give ALL the properties but the methods
              # are still not picked up, maybe because of the coffeescript construction system, I am not sure
              true
          ],
          [new Color(255, 165, 0),
            (element) =>
              # if the element is either an enumerable property of the object
              # or it belongs to the own methods, then it is highlighted.
              # Note that hasOwnProperty doesn't pick up non-enumerable properties such as
              # functions.
              # In theory, getOwnPropertyNames should give ALL the properties but the methods
              # are still not picked up, maybe because of the coffeescript construction system, I am not sure
              element in staticProperties
          ],
          [new Color(0, 180, 0),
            (element) =>
              # if the element is either an enumerable property of the object
              # or it belongs to the own methods, then it is highlighted.
              # Note that hasOwnProperty doesn't pick up non-enumerable properties such as
              # functions.
              # In theory, getOwnPropertyNames should give ALL the properties but the methods
              # are still not picked up, maybe because of the coffeescript construction system, I am not sure
              (Object.prototype.hasOwnProperty.call(@target, element))
          ],
          [new Color(180, 0, 0),
            (element) =>
              # if the element is either an enumerable property of the object
              # or it belongs to the own methods, then it is highlighted.
              # Note that hasOwnProperty doesn't pick up non-enumerable properties such as
              # functions.
              # In theory, getOwnPropertyNames should give ALL the properties but the methods
              # are still not picked up, maybe because of the coffeescript construction system, I am not sure
              (element in targetOwnMethods)
          ]
        ]
      else null
    ),doubleClickAction)

    # we know that the content of this list in this pane is not going to need the
    # step function, so we disable that from here by setting it to null, which
    # prevents the recursion to children. We could have disabled that from the
    # constructor of MenuMorph, but who knows, maybe someone might intend to use a MenuMorph
    # with some animated content? We know that in this specific case it won't need animation so
    # we set that here. Note that the ListMorph itself does require animation because of the
    # scrollbars, but the MenuMorph (which contains the actual list contents)
    # in this context doesn't.
    @list.listContents.step = null
    @add @list
    #
    # details pane
    @detail = new ScrollFrameMorph()
    @detail.acceptsDrops = false
    @detail.contents.acceptsDrops = false
    @detail.isTextLineWrapping = true
    @detail.color = new Color(255, 255, 255)
    ctrl = new TextMorph("")
    ctrl.isEditable = true
    ctrl.enableSelecting()
    ctrl.setReceiver @target
    @detail.setContents ctrl, 2
    @add @detail
    #
    # work ('evaluation') pane
    @work = new ScrollFrameMorph()
    @work.acceptsDrops = false
    @work.contents.acceptsDrops = false
    @work.isTextLineWrapping = true
    @work.color = new Color(255, 255, 255)
    ev = new TextMorph("")
    ev.isEditable = true
    ev.enableSelecting()
    ev.setReceiver @target
    @work.setContents ev, 2
    @add @work
    #
    # properties button
    @buttonSubset = new TriggerMorph(@)
    @buttonSubset.setLabel "show..."
    @buttonSubset.alignCenter()
    @buttonSubset.action = ->
      menu = new MenuMorph()
      menu.addItem "attributes", =>
        @showing = "attributes"
        @buildAndConnectChildren()
      #
      menu.addItem "methods", =>
        @showing = "methods"
        @buildAndConnectChildren()
      #
      menu.addItem "all", =>
        @showing = "all"
        @buildAndConnectChildren()
      #
      menu.addLine()
      menu.addItem ((if @markOwnershipOfProperties then "un-mark ownership" else "mark ownership")), (=>
        @markOwnershipOfProperties = not @markOwnershipOfProperties
        @buildAndConnectChildren()
      ), "highlight\nownership of properties"
      menu.popUpAtHand()
    #
    @add @buttonSubset
    #
    # inspect button
    @buttonInspect = new TriggerMorph(@)
    @buttonInspect.setLabel "inspect"
    @buttonInspect.alignCenter()
    @buttonInspect.action = ->
      if isObject(@currentProperty)
        menu = new MenuMorph()
        menu.addItem "in new inspector...", =>
          world = @world()
          inspector = new @constructor(@currentProperty)
          inspector.setPosition world.hand.position()
          inspector.keepWithin world
          world.add inspector
          inspector.changed()
        #
        menu.addItem "here...", =>
          @setTarget @currentProperty
        #
        menu.popUpAtHand()
      else
        @inform ((if @currentProperty is null then "null" else typeof @currentProperty)) + "\nis not inspectable"
    #
    @add @buttonInspect
    #
    # edit button
    @buttonEdit = new TriggerMorph(@)
    @buttonEdit.setLabel "edit..."
    @buttonEdit.alignCenter()
    @buttonEdit.action = ->
      menu = new MenuMorph(@)
      menu.addItem "save", (->@save()), "accept changes"
      menu.addLine()
      menu.addItem "add property...", (->@addProperty())
      menu.addItem "rename...", (->@renameProperty())
      menu.addItem "remove", (->@removeProperty())
      menu.popUpAtHand()
    #
    @add @buttonEdit
    #
    # close button
    @buttonClose = new TriggerMorph(@)
    @buttonClose.setLabel "close"
    @buttonClose.alignCenter()
    @buttonClose.action = ->
      @destroy()
    #
    @add @buttonClose
    #
    # resizer
    @resizer = new HandleMorph(@, 150, 100, @edge, @edge)
    #
    # update layout
    @layoutSubmorphs()

  selectionFromList: (selected) =>
    if (selected == undefined) then return
    val = @target[selected]
    # this is for finding the static variables
    if val is undefined
      val = @target.constructor[selected]
    @currentProperty = val
    if val is null
      txt = "null"
    else if isString(val)
      txt = '"'+val+'"'
    else
      txt = val.toString()
    cnts = new TextMorph(txt)
    cnts.isEditable = true
    cnts.enableSelecting()
    cnts.setReceiver @target
    @detail.setContents cnts, 2
  
  layoutSubmorphs: ->
    console.log "fixing the layout of the inspector"
    Morph::trackChanges = false
    #
    # label
    x = @left() + @edge
    y = @top() + @edge
    r = @right() - @edge
    w = r - x
    @label.setPosition new Point(x, y)
    @label.setWidth w
    if @label.height() > (@height() - 50)
      @silentSetHeight @label.height() + 50
      @updateRendering()
      @changed()
      @resizer.updatePosition()
    #
    # list
    y = @label.bottom() + 2
    w = Math.min(Math.floor(@width() / 3), @list.listContents.width())
    w -= @edge
    b = @bottom() - (2 * @edge) - WorldMorph.preferencesAndSettings.handleSize
    h = b - y
    @list.setPosition new Point(x, y)
    @list.setExtent new Point(w, h)
    #
    # detail
    x = @list.right() + @edge
    r = @right() - @edge
    w = r - x
    @detail.setPosition new Point(x, y)
    @detail.setExtent new Point(w, (h * 2 / 3) - @edge)
    #
    # work
    y = @detail.bottom() + @edge
    @work.setPosition new Point(x, y)
    @work.setExtent new Point(w, h / 3)
    #
    # properties button
    x = @list.left()
    y = @list.bottom() + @edge
    w = @list.width()
    h = WorldMorph.preferencesAndSettings.handleSize
    @buttonSubset.setPosition new Point(x, y)
    @buttonSubset.setExtent new Point(w, h)
    #
    # inspect button
    x = @detail.left()
    w = @detail.width() - @edge - WorldMorph.preferencesAndSettings.handleSize
    w = w / 3 - @edge / 3
    @buttonInspect.setPosition new Point(x, y)
    @buttonInspect.setExtent new Point(w, h)
    #
    # edit button
    x = @buttonInspect.right() + @edge
    @buttonEdit.setPosition new Point(x, y)
    #@buttonEdit.setPosition new Point(x, y + 20)
    @buttonEdit.setExtent new Point(w, h)
    #
    # close button
    x = @buttonEdit.right() + @edge
    r = @detail.right() - @edge - WorldMorph.preferencesAndSettings.handleSize
    w = r - x
    @buttonClose.setPosition new Point(x, y)
    @buttonClose.setExtent new Point(w, h)
    Morph::trackChanges = true
    @changed()
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.alignmentOfMorphIDsMechanism
      world.alignIDsOfNextMorphsInSystemTests()

  
  setExtent: (aPoint) ->
    super aPoint
    @layoutSubmorphs()
  
  
  #InspectorMorph editing ops:
  save: ->
    txt = @detail.contents.children[0].text.toString()
    propertyName = @list.selected.labelString
    try
      #
      # this.target[propertyName] = evaluate(txt);
      @target.evaluateString "this." + propertyName + " = " + txt
      if @target.updateRendering
        @target.changed()
        @target.updateRendering()
        @target.changed()
    catch err
      @inform err
  
  addProperty: ->
    @prompt "new property name:", ((prop) =>
      if prop?
        if prop.getValue?
          prop = prop.getValue()
        @target[prop] = null
        @buildAndConnectChildren()
        if @target.updateRendering
          @target.changed()
          @target.updateRendering()
          @target.changed()
    ), "property" # Chrome cannot handle empty strings (others do)
  
  renameProperty: ->
    propertyName = @list.selected.labelString
    @prompt "property name:", ((prop) =>
      if prop.getValue?
        prop = prop.getValue()
      try
        delete (@target[propertyName])
        @target[prop] = @currentProperty
      catch err
        @inform err
      @buildAndConnectChildren()
      if @target.updateRendering
        @target.changed()
        @target.updateRendering()
        @target.changed()
    ), propertyName
  
  removeProperty: ->
    propertyName = @list.selected.labelString
    try
      delete (@target[propertyName])
      #
      @currentProperty = null
      @buildAndConnectChildren()
      if @target.updateRendering
        @target.changed()
        @target.updateRendering()
        @target.changed()
    catch err
      @inform err

  @coffeeScriptSourceOfThisClass: '''
# InspectorMorph //////////////////////////////////////////////////////

class InspectorMorph extends BoxMorph

  target: null
  currentProperty: null
  showing: "attributes"
  markOwnershipOfProperties: false
  # panes:
  label: null
  list: null
  detail: null
  work: null
  buttonInspect: null
  buttonClose: null
  buttonSubset: null
  buttonEdit: null
  resizer: null

  constructor: (@target) ->
    super()
    # override inherited properties:
    @silentSetExtent new Point(WorldMorph.preferencesAndSettings.handleSize * 20,
      WorldMorph.preferencesAndSettings.handleSize * 20 * 2 / 3)
    @isDraggable = true
    @border = 1
    @edge = if WorldMorph.preferencesAndSettings.isFlat then 1 else 5
    @color = new Color(60, 60, 60)
    @borderColor = new Color(95, 95, 95)
    @buildAndConnectChildren()  if @target
  
  setTarget: (target) ->
    @target = target
    @currentProperty = null
    @buildAndConnectChildren()
  
  buildAndConnectChildren: ->
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.alignmentOfMorphIDsMechanism
      world.alignIDsOfNextMorphsInSystemTests()
    attribs = []
    #
    # remove existing panes
    @destroyAll()

    #
    @children = []
    #
    # label
    @label = new TextMorph(@target.toString())
    @label.fontSize = WorldMorph.preferencesAndSettings.menuFontSize
    @label.isBold = true
    @label.color = new Color(255, 255, 255)
    @add @label
    
    # properties list. Note that this picks up ALL properties
    # (enumerable such as strings and un-enumerable such as functions)
    # of the whole prototype chain.
    #
    #   a) some of these are DECLARED as part of the class that defines the object
    #   and are proprietary to the object. These are shown RED
    # 
    #   b) some of these are proprietary to the object but are initialised by
    #   code higher in the prototype chain. These are shown GREEN
    #
    #   c) some of these are not proprietary, i.e. they belong to an object up
    #   the chain of prototypes. These are shown BLUE
    #
    # todo: show the static methods and variables in yet another color.
    
    for property of @target
      # dummy condition, to be refined
      attribs.push property  if property
    if @showing is "attributes"
      attribs = attribs.filter((prop) =>
        not isFunction @target[prop]
      )
    else if @showing is "methods"
      attribs = attribs.filter((prop) =>
        isFunction @target[prop]
      )
    # otherwise show all properties
    # label getter
    # format list
    # format element: [color, predicate(element]
    
    staticProperties = Object.getOwnPropertyNames(@target.constructor)
    # get rid of all the standar fuff properties that are in classes
    staticProperties = staticProperties.filter((prop) =>
        prop not in ["name","length","prototype","caller","__super__","arguments"]
    )
    if @showing is "attributes"
      staticFunctions = []
      staticAttributes = staticProperties.filter((prop) =>
        not isFunction(@target.constructor[prop])
      )
    else if @showing is "methods"
      staticFunctions = staticProperties.filter((prop) =>
        isFunction(@target.constructor[prop])
      )
      staticAttributes = []
    else
      staticFunctions = staticProperties.filter((prop) =>
        isFunction(@target.constructor[prop])
      )
      staticAttributes = staticProperties.filter((prop) =>
        prop not in staticFunctions
      )
    #alert "stat fun " + staticFunctions + " stat attr " + staticAttributes
    attribs = (attribs.concat staticFunctions).concat staticAttributes
    #alert " all attribs " + attribs
    
    # caches the own methods of the object
    if @markOwnershipOfProperties
      targetOwnMethods = Object.getOwnPropertyNames(@target.constructor.prototype)
      #alert targetOwnMethods

    doubleClickAction = =>
      if (!isObject(@currentProperty))
        return
      world = @world()
      inspector = @constructor @currentProperty
      inspector.setPosition world.hand.position()
      inspector.keepWithin world
      world.add inspector
      inspector.changed()

    @list = new ListMorph(@, InspectorMorph.prototype.selectionFromList, (if @target instanceof Array then attribs else attribs.sort()), null,(
      if @markOwnershipOfProperties
        [
          # give color criteria from the most general to the most specific
          [new Color(0, 0, 180),
            (element) =>
              # if the element is either an enumerable property of the object
              # or it belongs to the own methods, then it is highlighted.
              # Note that hasOwnProperty doesn't pick up non-enumerable properties such as
              # functions.
              # In theory, getOwnPropertyNames should give ALL the properties but the methods
              # are still not picked up, maybe because of the coffeescript construction system, I am not sure
              true
          ],
          [new Color(255, 165, 0),
            (element) =>
              # if the element is either an enumerable property of the object
              # or it belongs to the own methods, then it is highlighted.
              # Note that hasOwnProperty doesn't pick up non-enumerable properties such as
              # functions.
              # In theory, getOwnPropertyNames should give ALL the properties but the methods
              # are still not picked up, maybe because of the coffeescript construction system, I am not sure
              element in staticProperties
          ],
          [new Color(0, 180, 0),
            (element) =>
              # if the element is either an enumerable property of the object
              # or it belongs to the own methods, then it is highlighted.
              # Note that hasOwnProperty doesn't pick up non-enumerable properties such as
              # functions.
              # In theory, getOwnPropertyNames should give ALL the properties but the methods
              # are still not picked up, maybe because of the coffeescript construction system, I am not sure
              (Object.prototype.hasOwnProperty.call(@target, element))
          ],
          [new Color(180, 0, 0),
            (element) =>
              # if the element is either an enumerable property of the object
              # or it belongs to the own methods, then it is highlighted.
              # Note that hasOwnProperty doesn't pick up non-enumerable properties such as
              # functions.
              # In theory, getOwnPropertyNames should give ALL the properties but the methods
              # are still not picked up, maybe because of the coffeescript construction system, I am not sure
              (element in targetOwnMethods)
          ]
        ]
      else null
    ),doubleClickAction)

    # we know that the content of this list in this pane is not going to need the
    # step function, so we disable that from here by setting it to null, which
    # prevents the recursion to children. We could have disabled that from the
    # constructor of MenuMorph, but who knows, maybe someone might intend to use a MenuMorph
    # with some animated content? We know that in this specific case it won't need animation so
    # we set that here. Note that the ListMorph itself does require animation because of the
    # scrollbars, but the MenuMorph (which contains the actual list contents)
    # in this context doesn't.
    @list.listContents.step = null
    @add @list
    #
    # details pane
    @detail = new ScrollFrameMorph()
    @detail.acceptsDrops = false
    @detail.contents.acceptsDrops = false
    @detail.isTextLineWrapping = true
    @detail.color = new Color(255, 255, 255)
    ctrl = new TextMorph("")
    ctrl.isEditable = true
    ctrl.enableSelecting()
    ctrl.setReceiver @target
    @detail.setContents ctrl, 2
    @add @detail
    #
    # work ('evaluation') pane
    @work = new ScrollFrameMorph()
    @work.acceptsDrops = false
    @work.contents.acceptsDrops = false
    @work.isTextLineWrapping = true
    @work.color = new Color(255, 255, 255)
    ev = new TextMorph("")
    ev.isEditable = true
    ev.enableSelecting()
    ev.setReceiver @target
    @work.setContents ev, 2
    @add @work
    #
    # properties button
    @buttonSubset = new TriggerMorph(@)
    @buttonSubset.setLabel "show..."
    @buttonSubset.alignCenter()
    @buttonSubset.action = ->
      menu = new MenuMorph()
      menu.addItem "attributes", =>
        @showing = "attributes"
        @buildAndConnectChildren()
      #
      menu.addItem "methods", =>
        @showing = "methods"
        @buildAndConnectChildren()
      #
      menu.addItem "all", =>
        @showing = "all"
        @buildAndConnectChildren()
      #
      menu.addLine()
      menu.addItem ((if @markOwnershipOfProperties then "un-mark ownership" else "mark ownership")), (=>
        @markOwnershipOfProperties = not @markOwnershipOfProperties
        @buildAndConnectChildren()
      ), "highlight\nownership of properties"
      menu.popUpAtHand()
    #
    @add @buttonSubset
    #
    # inspect button
    @buttonInspect = new TriggerMorph(@)
    @buttonInspect.setLabel "inspect"
    @buttonInspect.alignCenter()
    @buttonInspect.action = ->
      if isObject(@currentProperty)
        menu = new MenuMorph()
        menu.addItem "in new inspector...", =>
          world = @world()
          inspector = new @constructor(@currentProperty)
          inspector.setPosition world.hand.position()
          inspector.keepWithin world
          world.add inspector
          inspector.changed()
        #
        menu.addItem "here...", =>
          @setTarget @currentProperty
        #
        menu.popUpAtHand()
      else
        @inform ((if @currentProperty is null then "null" else typeof @currentProperty)) + "\nis not inspectable"
    #
    @add @buttonInspect
    #
    # edit button
    @buttonEdit = new TriggerMorph(@)
    @buttonEdit.setLabel "edit..."
    @buttonEdit.alignCenter()
    @buttonEdit.action = ->
      menu = new MenuMorph(@)
      menu.addItem "save", (->@save()), "accept changes"
      menu.addLine()
      menu.addItem "add property...", (->@addProperty())
      menu.addItem "rename...", (->@renameProperty())
      menu.addItem "remove", (->@removeProperty())
      menu.popUpAtHand()
    #
    @add @buttonEdit
    #
    # close button
    @buttonClose = new TriggerMorph(@)
    @buttonClose.setLabel "close"
    @buttonClose.alignCenter()
    @buttonClose.action = ->
      @destroy()
    #
    @add @buttonClose
    #
    # resizer
    @resizer = new HandleMorph(@, 150, 100, @edge, @edge)
    #
    # update layout
    @layoutSubmorphs()

  selectionFromList: (selected) =>
    if (selected == undefined) then return
    val = @target[selected]
    # this is for finding the static variables
    if val is undefined
      val = @target.constructor[selected]
    @currentProperty = val
    if val is null
      txt = "null"
    else if isString(val)
      txt = '"'+val+'"'
    else
      txt = val.toString()
    cnts = new TextMorph(txt)
    cnts.isEditable = true
    cnts.enableSelecting()
    cnts.setReceiver @target
    @detail.setContents cnts, 2
  
  layoutSubmorphs: ->
    console.log "fixing the layout of the inspector"
    Morph::trackChanges = false
    #
    # label
    x = @left() + @edge
    y = @top() + @edge
    r = @right() - @edge
    w = r - x
    @label.setPosition new Point(x, y)
    @label.setWidth w
    if @label.height() > (@height() - 50)
      @silentSetHeight @label.height() + 50
      @updateRendering()
      @changed()
      @resizer.updatePosition()
    #
    # list
    y = @label.bottom() + 2
    w = Math.min(Math.floor(@width() / 3), @list.listContents.width())
    w -= @edge
    b = @bottom() - (2 * @edge) - WorldMorph.preferencesAndSettings.handleSize
    h = b - y
    @list.setPosition new Point(x, y)
    @list.setExtent new Point(w, h)
    #
    # detail
    x = @list.right() + @edge
    r = @right() - @edge
    w = r - x
    @detail.setPosition new Point(x, y)
    @detail.setExtent new Point(w, (h * 2 / 3) - @edge)
    #
    # work
    y = @detail.bottom() + @edge
    @work.setPosition new Point(x, y)
    @work.setExtent new Point(w, h / 3)
    #
    # properties button
    x = @list.left()
    y = @list.bottom() + @edge
    w = @list.width()
    h = WorldMorph.preferencesAndSettings.handleSize
    @buttonSubset.setPosition new Point(x, y)
    @buttonSubset.setExtent new Point(w, h)
    #
    # inspect button
    x = @detail.left()
    w = @detail.width() - @edge - WorldMorph.preferencesAndSettings.handleSize
    w = w / 3 - @edge / 3
    @buttonInspect.setPosition new Point(x, y)
    @buttonInspect.setExtent new Point(w, h)
    #
    # edit button
    x = @buttonInspect.right() + @edge
    @buttonEdit.setPosition new Point(x, y)
    #@buttonEdit.setPosition new Point(x, y + 20)
    @buttonEdit.setExtent new Point(w, h)
    #
    # close button
    x = @buttonEdit.right() + @edge
    r = @detail.right() - @edge - WorldMorph.preferencesAndSettings.handleSize
    w = r - x
    @buttonClose.setPosition new Point(x, y)
    @buttonClose.setExtent new Point(w, h)
    Morph::trackChanges = true
    @changed()
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.alignmentOfMorphIDsMechanism
      world.alignIDsOfNextMorphsInSystemTests()

  
  setExtent: (aPoint) ->
    super aPoint
    @layoutSubmorphs()
  
  
  #InspectorMorph editing ops:
  save: ->
    txt = @detail.contents.children[0].text.toString()
    propertyName = @list.selected.labelString
    try
      #
      # this.target[propertyName] = evaluate(txt);
      @target.evaluateString "this." + propertyName + " = " + txt
      if @target.updateRendering
        @target.changed()
        @target.updateRendering()
        @target.changed()
    catch err
      @inform err
  
  addProperty: ->
    @prompt "new property name:", ((prop) =>
      if prop?
        if prop.getValue?
          prop = prop.getValue()
        @target[prop] = null
        @buildAndConnectChildren()
        if @target.updateRendering
          @target.changed()
          @target.updateRendering()
          @target.changed()
    ), "property" # Chrome cannot handle empty strings (others do)
  
  renameProperty: ->
    propertyName = @list.selected.labelString
    @prompt "property name:", ((prop) =>
      if prop.getValue?
        prop = prop.getValue()
      try
        delete (@target[propertyName])
        @target[prop] = @currentProperty
      catch err
        @inform err
      @buildAndConnectChildren()
      if @target.updateRendering
        @target.changed()
        @target.updateRendering()
        @target.changed()
    ), propertyName
  
  removeProperty: ->
    propertyName = @list.selected.labelString
    try
      delete (@target[propertyName])
      #
      @currentProperty = null
      @buildAndConnectChildren()
      if @target.updateRendering
        @target.changed()
        @target.updateRendering()
        @target.changed()
    catch err
      @inform err
  '''

# RectangleMorph /////////////////////////////////////////////////////////
# a plain rectangular Morph. Because it's so basic, it's the building
# block of many more complex constructions, for example containers
# , clipping windows, and clipping windows which allow content to be
# scrolled (clipping is particularly easy to do along a rectangular
# path and it allows many optimisations and it's a very common case)
# It's important that the basic unadulterated version of
# rectangle doesn't draw a border, to keep this basic
# and versatile, so for example there is no case where the children
# are painted over the border, which would look bad.

class RectangleMorph extends Morph
  constructor: (extent, color) ->
    super()
    @silentSetExtent(extent) if extent?
    @color = color if color?
  @coffeeScriptSourceOfThisClass: '''
# RectangleMorph /////////////////////////////////////////////////////////
# a plain rectangular Morph. Because it's so basic, it's the building
# block of many more complex constructions, for example containers
# , clipping windows, and clipping windows which allow content to be
# scrolled (clipping is particularly easy to do along a rectangular
# path and it allows many optimisations and it's a very common case)
# It's important that the basic unadulterated version of
# rectangle doesn't draw a border, to keep this basic
# and versatile, so for example there is no case where the children
# are painted over the border, which would look bad.

class RectangleMorph extends Morph
  constructor: (extent, color) ->
    super()
    @silentSetExtent(extent) if extent?
    @color = color if color?  '''

# LayoutAdjustingMorph

# this comment below is needed to figure our dependencies between classes

# This is a port of the
# respective Cuis Smalltalk classes (version 4.2-1766)
# Cuis is by Juan Vuletich


class LayoutAdjustingMorph extends RectangleMorph

  hand: null
  indicator: null

  constructor: ->

  @includeInNewMorphMenu: ->
    # Return true for all classes that can be instantiated from the menu
    return false

  ###
  adoptWidgetsColor: (paneColor) ->
    super adoptWidgetsColor paneColor
    @color = paneColord

  cursor: ->
    if @owner.direction == "#horizontal"
      Cursor.resizeLeft()
    else
      Cursor.resizeTop()
  ###

  @coffeeScriptSourceOfThisClass: '''
# LayoutAdjustingMorph

# this comment below is needed to figure our dependencies between classes

# This is a port of the
# respective Cuis Smalltalk classes (version 4.2-1766)
# Cuis is by Juan Vuletich


class LayoutAdjustingMorph extends RectangleMorph

  hand: null
  indicator: null

  constructor: ->

  @includeInNewMorphMenu: ->
    # Return true for all classes that can be instantiated from the menu
    return false

  ###
  adoptWidgetsColor: (paneColor) ->
    super adoptWidgetsColor paneColor
    @color = paneColord

  cursor: ->
    if @owner.direction == "#horizontal"
      Cursor.resizeLeft()
    else
      Cursor.resizeTop()
  ###
  '''

# Points //////////////////////////////////////////////////////////////

class Point

  x: null
  y: null
   
  constructor: (@x = 0, @y = 0) ->
  
  # Point string representation: e.g. '12@68'
  toString: ->
    Math.round(@x) + "@" + Math.round(@y)
  
  # Point copying:
  copy: ->
    new @constructor(@x, @y)
  
  # Point comparison:
  eq: (aPoint) ->
    # ==
    @x is aPoint.x and @y is aPoint.y
  
  lt: (aPoint) ->
    # <
    @x < aPoint.x and @y < aPoint.y
  
  gt: (aPoint) ->
    # >
    @x > aPoint.x and @y > aPoint.y
  
  ge: (aPoint) ->
    # >=
    @x >= aPoint.x and @y >= aPoint.y
  
  le: (aPoint) ->
    # <=
    @x <= aPoint.x and @y <= aPoint.y
  
  max: (aPoint) ->
    new @constructor(Math.max(@x, aPoint.x), Math.max(@y, aPoint.y))
  
  min: (aPoint) ->
    new @constructor(Math.min(@x, aPoint.x), Math.min(@y, aPoint.y))
  
  
  # Point conversion:
  round: ->
    new @constructor(Math.round(@x), Math.round(@y))
  
  abs: ->
    new @constructor(Math.abs(@x), Math.abs(@y))
  
  neg: ->
    new @constructor(-@x, -@y)
  
  mirror: ->
    new @constructor(@y, @x)
  
  floor: ->
    new @constructor(Math.max(Math.floor(@x), 0), Math.max(Math.floor(@y), 0))
  
  ceil: ->
    new @constructor(Math.ceil(@x), Math.ceil(@y))
  
  
  # Point arithmetic:
  add: (other) ->
    return new @constructor(@x + other.x, @y + other.y)  if other instanceof Point
    new @constructor(@x + other, @y + other)
  
  subtract: (other) ->
    return new @constructor(@x - other.x, @y - other.y)  if other instanceof Point
    new @constructor(@x - other, @y - other)
  
  multiplyBy: (other) ->
    return new @constructor(@x * other.x, @y * other.y)  if other instanceof Point
    new @constructor(@x * other, @y * other)
  
  divideBy: (other) ->
    return new @constructor(@x / other.x, @y / other.y)  if other instanceof Point
    new @constructor(@x / other, @y / other)
  
  floorDivideBy: (other) ->
    if other instanceof Point
      return new @constructor(Math.floor(@x / other.x), Math.floor(@y / other.y))
    new @constructor(Math.floor(@x / other), Math.floor(@y / other))
  
  
  # Point polar coordinates:
  r: ->
    t = (@multiplyBy(@))
    Math.sqrt t.x + t.y
  
  degrees: ->
    #
    #    answer the angle I make with origin in degrees.
    #    Right is 0, down is 90
    #
    if @x is 0
      return 90  if @y >= 0
      return 270
    tan = @y / @x
    theta = Math.atan(tan)
    if @x >= 0
      return degrees(theta)  if @y >= 0
      return 360 + (degrees(theta))
    180 + degrees(theta)
  
  theta: ->
    #
    #    answer the angle I make with origin in radians.
    #    Right is 0, down is 90
    #
    if @x is 0
      return radians(90)  if @y >= 0
      return radians(270)
    tan = @y / @x
    theta = Math.atan(tan)
    if @x >= 0
      return theta  if @y >= 0
      return radians(360) + theta
    radians(180) + theta
  
  
  # Point functions:
  distanceTo: (aPoint) ->
    (aPoint.subtract(@)).r()
  
  rotate: (direction, center) ->
    # direction must be 'right', 'left' or 'pi'
    offset = @subtract(center)
    return new @constructor(-offset.y, offset.y).add(center)  if direction is "right"
    return new @constructor(offset.y, -offset.y).add(center)  if direction is "left"
    #
    # direction === 'pi'
    center.subtract offset
  
  flip: (direction, center) ->
    # direction must be 'vertical' or 'horizontal'
    return new @constructor(@x, center.y * 2 - @y)  if direction is "vertical"
    #
    # direction === 'horizontal'
    new @constructor(center.x * 2 - @x, @y)
  
  distanceAngle: (dist, angle) ->
    deg = angle
    if deg > 270
      deg = deg - 360
    else deg = deg + 360  if deg < -270
    if -90 <= deg and deg <= 90
      x = Math.sin(radians(deg)) * dist
      y = Math.sqrt((dist * dist) - (x * x))
      return new @constructor(x + @x, @y - y)
    x = Math.sin(radians(180 - deg)) * dist
    y = Math.sqrt((dist * dist) - (x * x))
    new @constructor(x + @x, @y + y)
  
  
  # Point transforming:
  scaleBy: (scalePoint) ->
    @multiplyBy scalePoint
  
  translateBy: (deltaPoint) ->
    @add deltaPoint
  
  rotateBy: (angle, centerPoint) ->
    center = centerPoint or new @constructor(0, 0)
    p = @subtract(center)
    r = p.r()
    theta = angle - p.theta()
    new @constructor(center.x + (r * Math.cos(theta)), center.y - (r * Math.sin(theta)))
  
  
  # Point conversion:
  asArray: ->
    [@x, @y]
  
  # creating Rectangle instances from Points:
  corner: (cornerPoint) ->
    # answer a new Rectangle
    new Rectangle(@x, @y, cornerPoint.x, cornerPoint.y)
  
  rectangle: (aPoint) ->
    # answer a new Rectangle
    org = @min(aPoint)
    crn = @max(aPoint)
    new Rectangle(org.x, org.y, crn.x, crn.y)
  
  extent: (aPoint) ->
    #answer a new Rectangle
    crn = @add(aPoint)
    new Rectangle(@x, @y, crn.x, crn.y)

  @coffeeScriptSourceOfThisClass: '''
# Points //////////////////////////////////////////////////////////////

class Point

  x: null
  y: null
   
  constructor: (@x = 0, @y = 0) ->
  
  # Point string representation: e.g. '12@68'
  toString: ->
    Math.round(@x) + "@" + Math.round(@y)
  
  # Point copying:
  copy: ->
    new @constructor(@x, @y)
  
  # Point comparison:
  eq: (aPoint) ->
    # ==
    @x is aPoint.x and @y is aPoint.y
  
  lt: (aPoint) ->
    # <
    @x < aPoint.x and @y < aPoint.y
  
  gt: (aPoint) ->
    # >
    @x > aPoint.x and @y > aPoint.y
  
  ge: (aPoint) ->
    # >=
    @x >= aPoint.x and @y >= aPoint.y
  
  le: (aPoint) ->
    # <=
    @x <= aPoint.x and @y <= aPoint.y
  
  max: (aPoint) ->
    new @constructor(Math.max(@x, aPoint.x), Math.max(@y, aPoint.y))
  
  min: (aPoint) ->
    new @constructor(Math.min(@x, aPoint.x), Math.min(@y, aPoint.y))
  
  
  # Point conversion:
  round: ->
    new @constructor(Math.round(@x), Math.round(@y))
  
  abs: ->
    new @constructor(Math.abs(@x), Math.abs(@y))
  
  neg: ->
    new @constructor(-@x, -@y)
  
  mirror: ->
    new @constructor(@y, @x)
  
  floor: ->
    new @constructor(Math.max(Math.floor(@x), 0), Math.max(Math.floor(@y), 0))
  
  ceil: ->
    new @constructor(Math.ceil(@x), Math.ceil(@y))
  
  
  # Point arithmetic:
  add: (other) ->
    return new @constructor(@x + other.x, @y + other.y)  if other instanceof Point
    new @constructor(@x + other, @y + other)
  
  subtract: (other) ->
    return new @constructor(@x - other.x, @y - other.y)  if other instanceof Point
    new @constructor(@x - other, @y - other)
  
  multiplyBy: (other) ->
    return new @constructor(@x * other.x, @y * other.y)  if other instanceof Point
    new @constructor(@x * other, @y * other)
  
  divideBy: (other) ->
    return new @constructor(@x / other.x, @y / other.y)  if other instanceof Point
    new @constructor(@x / other, @y / other)
  
  floorDivideBy: (other) ->
    if other instanceof Point
      return new @constructor(Math.floor(@x / other.x), Math.floor(@y / other.y))
    new @constructor(Math.floor(@x / other), Math.floor(@y / other))
  
  
  # Point polar coordinates:
  r: ->
    t = (@multiplyBy(@))
    Math.sqrt t.x + t.y
  
  degrees: ->
    #
    #    answer the angle I make with origin in degrees.
    #    Right is 0, down is 90
    #
    if @x is 0
      return 90  if @y >= 0
      return 270
    tan = @y / @x
    theta = Math.atan(tan)
    if @x >= 0
      return degrees(theta)  if @y >= 0
      return 360 + (degrees(theta))
    180 + degrees(theta)
  
  theta: ->
    #
    #    answer the angle I make with origin in radians.
    #    Right is 0, down is 90
    #
    if @x is 0
      return radians(90)  if @y >= 0
      return radians(270)
    tan = @y / @x
    theta = Math.atan(tan)
    if @x >= 0
      return theta  if @y >= 0
      return radians(360) + theta
    radians(180) + theta
  
  
  # Point functions:
  distanceTo: (aPoint) ->
    (aPoint.subtract(@)).r()
  
  rotate: (direction, center) ->
    # direction must be 'right', 'left' or 'pi'
    offset = @subtract(center)
    return new @constructor(-offset.y, offset.y).add(center)  if direction is "right"
    return new @constructor(offset.y, -offset.y).add(center)  if direction is "left"
    #
    # direction === 'pi'
    center.subtract offset
  
  flip: (direction, center) ->
    # direction must be 'vertical' or 'horizontal'
    return new @constructor(@x, center.y * 2 - @y)  if direction is "vertical"
    #
    # direction === 'horizontal'
    new @constructor(center.x * 2 - @x, @y)
  
  distanceAngle: (dist, angle) ->
    deg = angle
    if deg > 270
      deg = deg - 360
    else deg = deg + 360  if deg < -270
    if -90 <= deg and deg <= 90
      x = Math.sin(radians(deg)) * dist
      y = Math.sqrt((dist * dist) - (x * x))
      return new @constructor(x + @x, @y - y)
    x = Math.sin(radians(180 - deg)) * dist
    y = Math.sqrt((dist * dist) - (x * x))
    new @constructor(x + @x, @y + y)
  
  
  # Point transforming:
  scaleBy: (scalePoint) ->
    @multiplyBy scalePoint
  
  translateBy: (deltaPoint) ->
    @add deltaPoint
  
  rotateBy: (angle, centerPoint) ->
    center = centerPoint or new @constructor(0, 0)
    p = @subtract(center)
    r = p.r()
    theta = angle - p.theta()
    new @constructor(center.x + (r * Math.cos(theta)), center.y - (r * Math.sin(theta)))
  
  
  # Point conversion:
  asArray: ->
    [@x, @y]
  
  # creating Rectangle instances from Points:
  corner: (cornerPoint) ->
    # answer a new Rectangle
    new Rectangle(@x, @y, cornerPoint.x, cornerPoint.y)
  
  rectangle: (aPoint) ->
    # answer a new Rectangle
    org = @min(aPoint)
    crn = @max(aPoint)
    new Rectangle(org.x, org.y, crn.x, crn.y)
  
  extent: (aPoint) ->
    #answer a new Rectangle
    crn = @add(aPoint)
    new Rectangle(@x, @y, crn.x, crn.y)
  '''

# Rectangles //////////////////////////////////////////////////////////

class Rectangle

  origin: null
  corner: null
  
  constructor: (left, top, right, bottom) ->
    
    @origin = new Point((left or 0), (top or 0))
    @corner = new Point((right or 0), (bottom or 0))
  
  
  # Rectangle string representation: e.g. '[0@0 | 160@80]'
  toString: ->
    "[" + @origin + " | " + @extent() + "]"
  
  # Rectangle copying:
  copy: ->
    new @constructor(@left(), @top(), @right(), @bottom())
  
  # Rectangle accessing - setting:
  setTo: (left, top, right, bottom) ->
    # note: all inputs are optional and can be omitted
    @origin = new Point(
      left or ((if (left is 0) then 0 else @left())),
      top or ((if (top is 0) then 0 else @top())))
    @corner = new Point(
      right or ((if (right is 0) then 0 else @right())),
      bottom or ((if (bottom is 0) then 0 else @bottom())))
  
  # Rectangle accessing - getting:
  area: ->
    #requires width() and height() to be defined
    w = @width()
    return 0  if w < 0
    Math.max w * @height(), 0
  
  bottom: ->
    @corner.y
  
  bottomCenter: ->
    new Point(@center().x, @bottom())
  
  bottomLeft: ->
    new Point(@origin.x, @corner.y)
  
  bottomRight: ->
    @corner.copy()
  
  boundingBox: ->
    @
  
  center: ->
    @origin.add @corner.subtract(@origin).floorDivideBy(2)
  
  corners: ->
    [@origin, @bottomLeft(), @corner, @topRight()]
  
  extent: ->
    @corner.subtract @origin
  
  isEmpty: ->
    # The subtract method creates a new Point
    theExtent = @corner.subtract @origin
    theExtent.x = 0 or theExtent.y = 0

  isNotEmpty: ->
    # The subtract method creates a new Point
    theExtent = @corner.subtract @origin
    theExtent.x > 0 and theExtent.y > 0
  
  height: ->
    @corner.y - @origin.y
  
  left: ->
    @origin.x
  
  leftCenter: ->
    new Point(@left(), @center().y)
  
  right: ->
    @corner.x
  
  rightCenter: ->
    new Point(@right(), @center().y)
  
  top: ->
    @origin.y
  
  topCenter: ->
    new Point(@center().x, @top())
  
  topLeft: ->
    @origin
  
  topRight: ->
    new Point(@corner.x, @origin.y)
  
  width: ->
    @corner.x - @origin.x
  
  position: ->
    @origin
  
  # Rectangle comparison:
  eq: (aRect) ->
    @origin.eq(aRect.origin) and @corner.eq(aRect.corner)
  
  abs: ->
    newOrigin = @origin.abs()
    newCorner = @corner.max(newOrigin)
    newOrigin.corner newCorner
  
  # Rectangle functions:
  insetBy: (delta) ->
    # delta can be either a Point or a Number
    result = new @constructor()
    result.origin = @origin.add(delta)
    result.corner = @corner.subtract(delta)
    result
  
  expandBy: (delta) ->
    # delta can be either a Point or a Number
    result = new @constructor()
    result.origin = @origin.subtract(delta)
    result.corner = @corner.add(delta)
    result
  
  growBy: (delta) ->
    # delta can be either a Point or a Number
    result = new @constructor()
    result.origin = @origin.copy()
    result.corner = @corner.add(delta)
    result
  
  intersect: (aRect) ->
    result = new @constructor()
    result.origin = @origin.max(aRect.origin)
    result.corner = @corner.min(aRect.corner)
    result
  
  merge: (aRect) ->
    result = new @constructor()
    result.origin = @origin.min(aRect.origin)
    result.corner = @corner.max(aRect.corner)
    result
  
  round: ->
    @origin.round().corner @corner.round()
  
  spread: ->
    # round me by applying floor() to my origin and ceil() to my corner
    @origin.floor().corner @corner.ceil()
  
  amountToTranslateWithin: (aRect) ->
    #
    #    Answer a Point, delta, such that self + delta is forced within
    #    aRectangle. when all of me cannot be made to fit, prefer to keep
    #    my topLeft inside. Taken from Squeak.
    #
    dx = aRect.right() - @right()  if @right() > aRect.right()
    dy = aRect.bottom() - @bottom()  if @bottom() > aRect.bottom()
    dx = aRect.left() - @left()  if (@left() + dx) < aRect.left()
    dy = aRect.top() - @top()  if (@top() + dy) < aRect.top()
    new Point(dx, dy)
  
  
  # Rectangle testing:
  containsPoint: (aPoint) ->
    @origin.le(aPoint) and aPoint.lt(@corner)
  
  containsRectangle: (aRect) ->
    aRect.origin.gt(@origin) and aRect.corner.lt(@corner)
  
  intersects: (aRect) ->
    ro = aRect.origin
    rc = aRect.corner
    (rc.x >= @origin.x) and
      (rc.y >= @origin.y) and
      (ro.x <= @corner.x) and
      (ro.y <= @corner.y)
  
  
  # Rectangle transforming:
  scaleBy: (scale) ->
    # scale can be either a Point or a scalar
    o = @origin.multiplyBy(scale)
    c = @corner.multiplyBy(scale)
    new @constructor(o.x, o.y, c.x, c.y)
  
  translateBy: (factor) ->
    # factor can be either a Point or a scalar
    o = @origin.add(factor)
    c = @corner.add(factor)
    new @constructor(o.x, o.y, c.x, c.y)
  
  
  # Rectangle converting:
  asArray: ->
    [@left(), @top(), @right(), @bottom()]
  
  asArray_xywh: ->
    [@left(), @top(), @width(), @height()]

  @coffeeScriptSourceOfThisClass: '''
# Rectangles //////////////////////////////////////////////////////////

class Rectangle

  origin: null
  corner: null
  
  constructor: (left, top, right, bottom) ->
    
    @origin = new Point((left or 0), (top or 0))
    @corner = new Point((right or 0), (bottom or 0))
  
  
  # Rectangle string representation: e.g. '[0@0 | 160@80]'
  toString: ->
    "[" + @origin + " | " + @extent() + "]"
  
  # Rectangle copying:
  copy: ->
    new @constructor(@left(), @top(), @right(), @bottom())
  
  # Rectangle accessing - setting:
  setTo: (left, top, right, bottom) ->
    # note: all inputs are optional and can be omitted
    @origin = new Point(
      left or ((if (left is 0) then 0 else @left())),
      top or ((if (top is 0) then 0 else @top())))
    @corner = new Point(
      right or ((if (right is 0) then 0 else @right())),
      bottom or ((if (bottom is 0) then 0 else @bottom())))
  
  # Rectangle accessing - getting:
  area: ->
    #requires width() and height() to be defined
    w = @width()
    return 0  if w < 0
    Math.max w * @height(), 0
  
  bottom: ->
    @corner.y
  
  bottomCenter: ->
    new Point(@center().x, @bottom())
  
  bottomLeft: ->
    new Point(@origin.x, @corner.y)
  
  bottomRight: ->
    @corner.copy()
  
  boundingBox: ->
    @
  
  center: ->
    @origin.add @corner.subtract(@origin).floorDivideBy(2)
  
  corners: ->
    [@origin, @bottomLeft(), @corner, @topRight()]
  
  extent: ->
    @corner.subtract @origin
  
  isEmpty: ->
    # The subtract method creates a new Point
    theExtent = @corner.subtract @origin
    theExtent.x = 0 or theExtent.y = 0

  isNotEmpty: ->
    # The subtract method creates a new Point
    theExtent = @corner.subtract @origin
    theExtent.x > 0 and theExtent.y > 0
  
  height: ->
    @corner.y - @origin.y
  
  left: ->
    @origin.x
  
  leftCenter: ->
    new Point(@left(), @center().y)
  
  right: ->
    @corner.x
  
  rightCenter: ->
    new Point(@right(), @center().y)
  
  top: ->
    @origin.y
  
  topCenter: ->
    new Point(@center().x, @top())
  
  topLeft: ->
    @origin
  
  topRight: ->
    new Point(@corner.x, @origin.y)
  
  width: ->
    @corner.x - @origin.x
  
  position: ->
    @origin
  
  # Rectangle comparison:
  eq: (aRect) ->
    @origin.eq(aRect.origin) and @corner.eq(aRect.corner)
  
  abs: ->
    newOrigin = @origin.abs()
    newCorner = @corner.max(newOrigin)
    newOrigin.corner newCorner
  
  # Rectangle functions:
  insetBy: (delta) ->
    # delta can be either a Point or a Number
    result = new @constructor()
    result.origin = @origin.add(delta)
    result.corner = @corner.subtract(delta)
    result
  
  expandBy: (delta) ->
    # delta can be either a Point or a Number
    result = new @constructor()
    result.origin = @origin.subtract(delta)
    result.corner = @corner.add(delta)
    result
  
  growBy: (delta) ->
    # delta can be either a Point or a Number
    result = new @constructor()
    result.origin = @origin.copy()
    result.corner = @corner.add(delta)
    result
  
  intersect: (aRect) ->
    result = new @constructor()
    result.origin = @origin.max(aRect.origin)
    result.corner = @corner.min(aRect.corner)
    result
  
  merge: (aRect) ->
    result = new @constructor()
    result.origin = @origin.min(aRect.origin)
    result.corner = @corner.max(aRect.corner)
    result
  
  round: ->
    @origin.round().corner @corner.round()
  
  spread: ->
    # round me by applying floor() to my origin and ceil() to my corner
    @origin.floor().corner @corner.ceil()
  
  amountToTranslateWithin: (aRect) ->
    #
    #    Answer a Point, delta, such that self + delta is forced within
    #    aRectangle. when all of me cannot be made to fit, prefer to keep
    #    my topLeft inside. Taken from Squeak.
    #
    dx = aRect.right() - @right()  if @right() > aRect.right()
    dy = aRect.bottom() - @bottom()  if @bottom() > aRect.bottom()
    dx = aRect.left() - @left()  if (@left() + dx) < aRect.left()
    dy = aRect.top() - @top()  if (@top() + dy) < aRect.top()
    new Point(dx, dy)
  
  
  # Rectangle testing:
  containsPoint: (aPoint) ->
    @origin.le(aPoint) and aPoint.lt(@corner)
  
  containsRectangle: (aRect) ->
    aRect.origin.gt(@origin) and aRect.corner.lt(@corner)
  
  intersects: (aRect) ->
    ro = aRect.origin
    rc = aRect.corner
    (rc.x >= @origin.x) and
      (rc.y >= @origin.y) and
      (ro.x <= @corner.x) and
      (ro.y <= @corner.y)
  
  
  # Rectangle transforming:
  scaleBy: (scale) ->
    # scale can be either a Point or a scalar
    o = @origin.multiplyBy(scale)
    c = @corner.multiplyBy(scale)
    new @constructor(o.x, o.y, c.x, c.y)
  
  translateBy: (factor) ->
    # factor can be either a Point or a scalar
    o = @origin.add(factor)
    c = @corner.add(factor)
    new @constructor(o.x, o.y, c.x, c.y)
  
  
  # Rectangle converting:
  asArray: ->
    [@left(), @top(), @right(), @bottom()]
  
  asArray_xywh: ->
    [@left(), @top(), @width(), @height()]
  '''

# LayoutMorph

# this comment below is needed to figure our dependencies between classes
# REQUIRES Color
# REQUIRES Point
# REQUIRES Rectangle

# This is a port of the
# respective Cuis Smalltalk classes (version 4.2-1766)
# Cuis is by Juan Vuletich

# A row or column of widgets, does layout by placing
# them either horizontally or vertically.

# Submorphs might specify a LayoutSpec.
# If some don't, then, for a column, the column
# width is taken as the width, and any morph height
# is kept. Same for rows: submorph width would be
# maintained, and submorph height would be made
# equal to row height.

class LayoutMorph extends Morph

  instanceVariableNames: 'direction separation padding'
  classVariableNames: ''
  poolDictionaries: ''
  category: 'Morphic-Layouts'

  direction: ""
  padding: 0
  separation: null # contains a Point
  layoutNeeded: false

  constructor: ->
    super()
    @separation = new Point 0,0
  
  @newColumn: ->
    newLayoutMorph =  new @()
    newLayoutMorph.beColumn()
    return newLayoutMorph

  @newRow: ->
    #debugger
    newLayoutMorph =  new @()
    newLayoutMorph.beRow()
    return newLayoutMorph

  beColumn: ->
    @direction = "#vertical"
    @setPadding "#center"

  beRow: ->
    @direction = "#horizontal"
    @setPadding= "#left"

  defaultColor: ->
    return Color.transparent()

  # This sets how extra space is used when doing layout.
  # For example, a column might have extra , unneded
  # vertical space. #top means widgets are set close
  # to the top, and extra space is at bottom. Conversely,
  # #bottom means widgets are set close to the bottom,
  # and extra space is at top. Valid values include
  # #left and #right (for rows) and #center. Alternatively,
  # any number between 0.0 and 1.0 might be used.
  #   self new padding: #center
  #   self new padding: 0.9
  setPadding: (howMuchPadding) ->
    switch howMuchPadding
      when "#top" then @padding = 0.0
      when "#left" then @padding = 0.0
      when "#center" then @padding = 0.5
      when "#right" then @padding = 1.0
      when "#bottom" then @padding = 1.0
      else @padding = howMuchPadding

  setSeparation: (howMuchSeparation) ->
    @separation = howMuchSeparation

  xSeparation: ->
    return @separation.x

  ySeparation: ->
    return @separation.y

  # Compute a new layout based on the given layout bounds
  layoutSubmorphs: ->
    console.log "layoutSubmorphs in LayoutMorph"
    #debugger
    if @children.length == 0
      @layoutNeeded = false
      return @

    if @direction == "#horizontal"
      @layoutSubmorphsHorizontallyIn @bounds

    if @direction == "#vertical"
      @layoutSubmorphsVerticallyIn @bounds

    @layoutNeeded = false

  # Compute a new layout based on the given layout bounds.
  layoutSubmorphsHorizontallyIn: (boundsForLayout) ->
    #| xSep ySep usableWidth sumOfFixed normalizationFactor availableForPropWidth widths l usableHeight boundsTop boundsRight t |
    xSep = @xSeparation()
    ySep = @ySeparation()
    usableWidth = boundsForLayout.width() - ((@children.length + 1) * xSep)
    sumOfFixed = 0
    @children.forEach (child) =>
      if child.layoutSpec?
        if child.layoutSpec.fixedWidth?
          sumOfFixed += child.layoutSpec.getFixedWidth()
    availableForPropWidth = usableWidth - sumOfFixed
    normalizationFactor = @proportionalWidthNormalizationFactor()
    availableForPropWidth = availableForPropWidth * normalizationFactor
    widths = []
    sumOfWidths = 0
    @children.forEach (child) =>
      if child.layoutSpec?
        #debugger
        theWidth = child.layoutSpec.widthFor availableForPropWidth
        sumOfWidths += theWidth
        widths.push theWidth
    l = ((usableWidth - sumOfWidths) * @padding + Math.max(xSep, 0)) +  boundsForLayout.left()
    usableHeight = boundsForLayout.height() - Math.max(2*ySep,0)
    boundsTop = boundsForLayout.top()
    boundsRight = boundsForLayout.right()
    for i in [@children.length-1 .. 0]
      m = @children[i]
      # major direction
      w = widths[i]
      # minor direction
      ls = m.layoutSpec
      if not ls?
        # there might be submorphs that don't have a layout.
        # for example, currently, the HandleMorph can be attached
        # to the LayoutMorph without a layoutSpec.
        # just skip those. The HandleMorph does its own
        # layouting.
        continue
      h = Math.min(usableHeight, ls.heightFor(usableHeight))
      t = (usableHeight - h) * ls.minorDirectionPadding + ySep + boundsTop
      # Set bounds and adjust major direction for next step
      # self flag: #jmvVer2.
      # should extent be set in m's coordinate system? what if its scale is not 1?
      m.setPosition(new Point(l,t))
      #debugger
      m.setExtent(new Point(Math.min(w,boundsForLayout.width()),h))
      if w>0
        l = Math.min(l + w + xSep, boundsRight)

  # this is the symmetric of the previous method
  layoutSubmorphsVerticallyIn: (boundsForLayout) ->
    usableHeight boundsTop boundsRight t |
    xSep = @xSeparation()
    ySep = @ySeparation()
    usableWidth = boundsForLayout.height() - ((@children.length + 1) * ySep)
    sumOfFixed = 0
    @children.forEach (child) =>
      if child.layoutSpec?
        if child.layoutSpec.fixedWidth?
          sumOfFixed += child.layoutSpec.fixedHeight
    availableForPropHeight = usableHeight - sumOfFixed
    normalizationFactor = @proportionalHeightNormalizationFactor
    availableForPropHeight = availableForPropHeight * normalizationFactor
    heights = []
    sumOfHeights = 0
    @children.forEach (child) =>
      if child.layoutSpec?
        theHeight = child.layoutSpec.heightFor availableForPropHeight
        sumOfHeights += theHeight
        heights.push theHeight
    t = ((usableHeight - sumOfHeights) * @padding + Math.max(ySep, 0)) +  boundsForLayout.top()
    usableWidth = boundsForLayout.width() - Math.max(2*xSep,0)
    boundsBottom = boundsForLayout.bottom()
    boundsLeft = boundsForLayout.left()
    for i in [children.length-1 .. 0]
      m = @children[i]
      # major direction
      h = heights[i]
      # minor direction
      ls = m.layoutSpec
      w = Math.min(usableWidth, ls.widthFor(usableWidth))
      l = (usableWidth - w) * ls.minorDirectionPadding() + xSep + boundsLeft
      # Set bounds and adjust major direction for next step
      # self flag: #jmvVer2.
      # should extent be set in m's coordinate system? what if its scale is not 1?
      m.setPosition(new Point(l,t))
      m.setExtent(Math.min(w,boundsForLayout.height()),h)
      if h>0
        t = Math.min(t + h + ySep, boundsBottom)

  # So the user can adjust layout
  addAdjusterMorph: ->
    thickness = 4

    if @direction == "#horizontal"
      @addMorph( new LayoutAdjustingMorph() )
      @layoutSpec = LayoutSpec.fixedWidth(thickness)

    if @direction == "#vertical"
      @addMorph( new LayoutAdjustingMorph() )
      @layoutSpec = LayoutSpec.fixedHeight(thickness)

  #"Add a submorph, at the bottom or right, with aLayoutSpec"
  addMorphWithLayoutSpec: (aMorph, aLayoutSpec) ->
    aMorph.layoutSpec = aLayoutSpec
    @addMorph aMorph

  minPaneHeightForReframe: ->
    return 20

  minPaneWidthForReframe: ->
    return 40

  proportionalHeightNormalizationFactor: ->
    sumOfProportional = 0
    @children.forEach (child) =>
      if child.layoutSpec?
        sumOfProportional += child.layoutSpec.proportionalHeight()
    return 1.0/Math.max(sumOfProportional, 1.0)

  proportionalWidthNormalizationFactor: ->
    sumOfProportional = 0
    @children.forEach (child) =>
      if child.layoutSpec?
        sumOfProportional += child.layoutSpec.getProportionalWidth()
    return 1.0/Math.max(sumOfProportional, 1.0)

  adjustByAt: (aLayoutAdjustMorph, aPoint) ->
    if @direction == "#horizontal"
      @adjustHorizontallyByAt aLayoutAdjustMorph, aPoint

    if @direction == "#vertical"
      @adjustVerticallyByAt aLayoutAdjustMorph, aPoint

  adjustHorizontallyByAt: (aLayoutAdjustMorph, aPoint) ->
    # | delta l ls r rs lNewWidth rNewWidth i lCurrentWidth rCurrentWidth doNotResizeBelow |
    doNotResizeBelow =  @minPaneWidthForReframe
    i = @children[aLayoutAdjustMorph]
    l = @children[i+1]
    ls = l.layoutSpec
    lCurrentWidth = Math.max(l.morphWidth(),1) # avoid division by zero
    r = @children[i - 1]
    rs = r.layoutSpec
    rCurrentWidth = Math.max(r.morphWidth(),1) # avoid division by zero
    delta = aPoint.x - aLayoutAdjustMorph.position().x
    delta = Math.max(delta, doNotResizeBelow - lCurrentWidth)
    delta = Math.min(delta, rCurrentWidth - doNotResizeBelow)
    if delta == 0 then return @
    rNewWidth = rCurrentWidth - delta
    lNewWidth = lCurrentWidth + delta
    if ls.isProportionalWidth() and rs.isProportionalWidth()
      # If both proportional, update them
      ls.setProportionalWidth 1.0 * lNewWidth / lCurrentWidth * ls.proportionalWidth()
      rs.setProportionalWidth 1.0 * rNewWidth / rCurrentWidth * rs.proportionalWidth()
    else
      # If at least one is fixed, update only the fixed
      if !ls.isProportionalWidth()
          ls.fixedOrMorphWidth lNewWidth
      if !rs.isProportionalWidth()
          rs.fixedOrMorphWidth rNewWidth
    @layoutSubmorphs()

  adjustVerticallyByAt: (aLayoutAdjustMorph, aPoint) ->
    # | delta t ts b bs tNewHeight bNewHeight i tCurrentHeight bCurrentHeight doNotResizeBelow |
    doNotResizeBelow = @minPaneHeightForReframe()
    i = @children[aLayoutAdjustMorph]
    t = @children[i+1]
    ts = t.layoutSpec()
    tCurrentHeight = Math.max(t.morphHeight(),1) # avoid division by zero
    b = @children[i - 1]
    bs = b.layoutSpec
    bCurrentHeight = Math.max(b.morphHeight(),1) # avoid division by zero
    delta = aPoint.y - aLayoutAdjustMorph.position().y
    delta = Math.max(delta, doNotResizeBelow - tCurrentHeight)
    delta = Math.min(delta, bCurrentHeight - doNotResizeBelow)
    if delta == 0 then return @
    tNewHeight = tCurrentHeight + delta
    bNewHeight = bCurrentHeight - delta
    if ts.isProportionalHeight() and bs.isProportionalHeight()
      # If both proportional, update them
      ts.setProportionalHeight 1.0 * tNewHeight / tCurrentHeight * ts.proportionalHeight()
      bs.setProportionalHeight 1.0 * bNewHeight / bCurrentHeight * bs.proportionalHeight()
    else
      # If at least one is fixed, update only the fixed
      if !ts.isProportionalHeight()
          ts.fixedOrMorphHeight tNewHeight
      if !bs.isProportionalHeight()
          bs.fixedOrMorphHeight bNewHeight
    @layoutSubmorphs()

  #####################
  # convenience methods
  #####################

  addAdjusterAndMorphFixedHeight: (aMorph,aNumber) ->
    @addAdjusterAndMorphLayoutSpec(aMorph, LayoutSpec.newWithFixedHeight aNumber)

  addAdjusterAndMorphLayoutSpec: (aMorph, aLayoutSpec) ->
    #Add a submorph, at the bottom or right, with aLayoutSpec"
    @addAdjusterMorph()
    @addMorphLayoutSpec(aMorph, aLayoutSpec)

  addAdjusterAndMorphProportionalHeight: (aMorph, aNumber) ->
    @addAdjusterAndMorphLayoutSpec(aMorph, LayoutSpec.newWithProportionalHeight(aNumber))

  addAdjusterAndMorphProportionalWidth: (aMorph, aNumber) ->
    @addAdjusterAndMorphLayoutSpec(aMorph, LayoutSpec.newWithProportionalWidth(aNumber))

  addMorphFixedHeight: (aMorph, aNumber) ->
    @addMorphLayoutSpec(aMorph, LayoutSpec.newWithFixedHeight(aNumber))

  addMorphFixedWidth: (aMorph, aNumber) ->
    @addMorphLayoutSpec(aMorph, LayoutSpec.newWithFixedWidth(aNumber))

  addMorphLayoutSpec: (aMorph, aLayoutSpec) ->
    # Add a submorph, at the bottom or right, with aLayoutSpec
    aMorph.layoutSpec = aLayoutSpec
    @add aMorph

  addMorphProportionalHeight: (aMorph, aNumber) ->
    @addMorphLayoutSpec(aMorph, LayoutSpec.newWithProportionalHeight(aNumber))

  addMorphProportionalWidth: (aMorph, aNumber) ->
    @addMorphLayoutSpec(aMorph, LayoutSpec.newWithProportionalWidth(aNumber))

  addMorphUseAll: (aMorph) ->
    @addMorphLayoutSpec(aMorph, LayoutSpec.useAll())

  addMorphs: (morphs) ->
    morphs.forEach (morph) =>
      @addMorphProportionalWidth(m,1)

  addMorphsWidthProportionalTo: (morphs, widths) ->
    morphs.forEach (morph) =>
      @addMorphProportionalWidth(m,w)

  # unclear how to translate this one for the time being
  is: (aSymbol) ->
    return aSymbol == "#LayoutMorph" # or [ super is: aSymbol ]

  @test1: ->
    rect1 = new RectangleMorph(new Point(20,20), new Color(255,0,0));
    rect2 = new RectangleMorph(new Point(20,20), new Color(0,255,0));
    row = LayoutMorph.newRow()
    row.addMorphProportionalWidth(rect1,2)
    row.addMorphProportionalWidth(rect2,1)
    row.layoutSubmorphs()
    row.setPosition(world.hand.position());
    row.keepWithin(world);
    world.add(row);
    row.changed();

    # attach a HandleMorph to it so that
    # we can check how it resizes
    handle = new HandleMorph()
    handle.isDraggable = false
    handle.target = row
    handle.updateRendering()
    handle.noticesTransparentClick = true

  @test2: ->
    rect3 = new RectangleMorph(new Point(20,20), new Color(255,0,0));
    rect4 = new RectangleMorph(new Point(20,20), new Color(0,255,0));
    row2 = LayoutMorph.newRow()
    row2.addMorphFixedWidth(rect3,10)
    row2.addMorphProportionalWidth(rect4,1)
    row2.layoutSubmorphs()
    row2.setPosition(world.hand.position());
    row2.keepWithin(world);
    world.add(row2);
    row2.changed();

    # attach a HandleMorph to it so that
    # we can check how it resizes
    handle = new HandleMorph()
    handle.isDraggable = false
    handle.target = row2
    handle.updateRendering()
    handle.noticesTransparentClick = true

  @test3: ->
    rect5 = new RectangleMorph(new Point(20,20), new Color(255,0,0));
    rect6 = new RectangleMorph(new Point(20,20), new Color(0,255,0));
    rect7 = new RectangleMorph(new Point(20,20), new Color(0,0,255));
    row3 = LayoutMorph.newRow()
    row3.addMorphProportionalWidth(rect6,2)
    row3.addMorphFixedWidth(rect5,10)
    row3.addMorphProportionalWidth(rect7,1)
    row3.layoutSubmorphs()
    row3.setPosition(world.hand.position());
    row3.keepWithin(world);
    world.add(row3);
    row3.changed();

    # attach a HandleMorph to it so that
    # we can check how it resizes
    handle = new HandleMorph()
    handle.isDraggable = false
    handle.target = row3
    handle.updateRendering()
    handle.noticesTransparentClick = true

  @test4: ->
    # //////////////////////////////////////////////////
    # note how the vertical spacing in the horizontal layout
    # is different. the vertical size is not adjusted considering
    # all other morphs. A proportional of 1.1 is proportional to the
    # container, not to the other layouts.
    # Equivalent smalltalk code:
    # | pane rect1 rect2 |
    # pane _ LayoutMorph newRow separation: 5. "3"
    # pane addMorph: (StringMorph contents: '3').
    # 
    # rect1 := BorderedRectMorph new color: (Color lightOrange).
    # pane addMorph: rect1 
    #          layoutSpec: (LayoutSpec  fixedWidth: 20 proportionalHeight: 1.1 minorDirectionPadding: #center).
    # rect2 := BorderedRectMorph new color: (Color cyan);
    #   layoutSpec: (LayoutSpec  fixedWidth: 20 proportionalHeight: 0.5 minorDirectionPadding: #center).
    # pane addMorph: rect2.
    # pane
    #   color: Color lightGreen;
    #   openInWorld;
    #   morphPosition: 520 @ 50;
    #   morphExtent: 180 @ 100
    # //////////////////////////////////////////////////

    rect5 = new RectangleMorph(new Point(20,20), new Color(255,0,0));
    rect6 = new RectangleMorph(new Point(20,20), new Color(0,255,0));
    rect7 = new RectangleMorph(new Point(20,20), new Color(0,0,255));
    row3 = LayoutMorph.newRow()
    row3.addMorphProportionalHeight(rect6,0.5)
    row3.addMorphFixedHeight(rect5,200)
    row3.addMorphProportionalHeight(rect7,1.1)
    row3.layoutSubmorphs()
    row3.setPosition(world.hand.position());
    row3.keepWithin(world);
    world.add(row3);
    row3.changed();

    # attach a HandleMorph to it so that
    # we can check how it resizes
    handle = new HandleMorph()
    handle.isDraggable = false
    handle.target = row3
    handle.updateRendering()
    handle.noticesTransparentClick = true #

  @coffeeScriptSourceOfThisClass: '''
# LayoutMorph

# this comment below is needed to figure our dependencies between classes
# REQUIRES Color
# REQUIRES Point
# REQUIRES Rectangle

# This is a port of the
# respective Cuis Smalltalk classes (version 4.2-1766)
# Cuis is by Juan Vuletich

# A row or column of widgets, does layout by placing
# them either horizontally or vertically.

# Submorphs might specify a LayoutSpec.
# If some don't, then, for a column, the column
# width is taken as the width, and any morph height
# is kept. Same for rows: submorph width would be
# maintained, and submorph height would be made
# equal to row height.

class LayoutMorph extends Morph

  instanceVariableNames: 'direction separation padding'
  classVariableNames: ''
  poolDictionaries: ''
  category: 'Morphic-Layouts'

  direction: ""
  padding: 0
  separation: null # contains a Point
  layoutNeeded: false

  constructor: ->
    super()
    @separation = new Point 0,0
  
  @newColumn: ->
    newLayoutMorph =  new @()
    newLayoutMorph.beColumn()
    return newLayoutMorph

  @newRow: ->
    #debugger
    newLayoutMorph =  new @()
    newLayoutMorph.beRow()
    return newLayoutMorph

  beColumn: ->
    @direction = "#vertical"
    @setPadding "#center"

  beRow: ->
    @direction = "#horizontal"
    @setPadding= "#left"

  defaultColor: ->
    return Color.transparent()

  # This sets how extra space is used when doing layout.
  # For example, a column might have extra , unneded
  # vertical space. #top means widgets are set close
  # to the top, and extra space is at bottom. Conversely,
  # #bottom means widgets are set close to the bottom,
  # and extra space is at top. Valid values include
  # #left and #right (for rows) and #center. Alternatively,
  # any number between 0.0 and 1.0 might be used.
  #   self new padding: #center
  #   self new padding: 0.9
  setPadding: (howMuchPadding) ->
    switch howMuchPadding
      when "#top" then @padding = 0.0
      when "#left" then @padding = 0.0
      when "#center" then @padding = 0.5
      when "#right" then @padding = 1.0
      when "#bottom" then @padding = 1.0
      else @padding = howMuchPadding

  setSeparation: (howMuchSeparation) ->
    @separation = howMuchSeparation

  xSeparation: ->
    return @separation.x

  ySeparation: ->
    return @separation.y

  # Compute a new layout based on the given layout bounds
  layoutSubmorphs: ->
    console.log "layoutSubmorphs in LayoutMorph"
    #debugger
    if @children.length == 0
      @layoutNeeded = false
      return @

    if @direction == "#horizontal"
      @layoutSubmorphsHorizontallyIn @bounds

    if @direction == "#vertical"
      @layoutSubmorphsVerticallyIn @bounds

    @layoutNeeded = false

  # Compute a new layout based on the given layout bounds.
  layoutSubmorphsHorizontallyIn: (boundsForLayout) ->
    #| xSep ySep usableWidth sumOfFixed normalizationFactor availableForPropWidth widths l usableHeight boundsTop boundsRight t |
    xSep = @xSeparation()
    ySep = @ySeparation()
    usableWidth = boundsForLayout.width() - ((@children.length + 1) * xSep)
    sumOfFixed = 0
    @children.forEach (child) =>
      if child.layoutSpec?
        if child.layoutSpec.fixedWidth?
          sumOfFixed += child.layoutSpec.getFixedWidth()
    availableForPropWidth = usableWidth - sumOfFixed
    normalizationFactor = @proportionalWidthNormalizationFactor()
    availableForPropWidth = availableForPropWidth * normalizationFactor
    widths = []
    sumOfWidths = 0
    @children.forEach (child) =>
      if child.layoutSpec?
        #debugger
        theWidth = child.layoutSpec.widthFor availableForPropWidth
        sumOfWidths += theWidth
        widths.push theWidth
    l = ((usableWidth - sumOfWidths) * @padding + Math.max(xSep, 0)) +  boundsForLayout.left()
    usableHeight = boundsForLayout.height() - Math.max(2*ySep,0)
    boundsTop = boundsForLayout.top()
    boundsRight = boundsForLayout.right()
    for i in [@children.length-1 .. 0]
      m = @children[i]
      # major direction
      w = widths[i]
      # minor direction
      ls = m.layoutSpec
      if not ls?
        # there might be submorphs that don't have a layout.
        # for example, currently, the HandleMorph can be attached
        # to the LayoutMorph without a layoutSpec.
        # just skip those. The HandleMorph does its own
        # layouting.
        continue
      h = Math.min(usableHeight, ls.heightFor(usableHeight))
      t = (usableHeight - h) * ls.minorDirectionPadding + ySep + boundsTop
      # Set bounds and adjust major direction for next step
      # self flag: #jmvVer2.
      # should extent be set in m's coordinate system? what if its scale is not 1?
      m.setPosition(new Point(l,t))
      #debugger
      m.setExtent(new Point(Math.min(w,boundsForLayout.width()),h))
      if w>0
        l = Math.min(l + w + xSep, boundsRight)

  # this is the symmetric of the previous method
  layoutSubmorphsVerticallyIn: (boundsForLayout) ->
    usableHeight boundsTop boundsRight t |
    xSep = @xSeparation()
    ySep = @ySeparation()
    usableWidth = boundsForLayout.height() - ((@children.length + 1) * ySep)
    sumOfFixed = 0
    @children.forEach (child) =>
      if child.layoutSpec?
        if child.layoutSpec.fixedWidth?
          sumOfFixed += child.layoutSpec.fixedHeight
    availableForPropHeight = usableHeight - sumOfFixed
    normalizationFactor = @proportionalHeightNormalizationFactor
    availableForPropHeight = availableForPropHeight * normalizationFactor
    heights = []
    sumOfHeights = 0
    @children.forEach (child) =>
      if child.layoutSpec?
        theHeight = child.layoutSpec.heightFor availableForPropHeight
        sumOfHeights += theHeight
        heights.push theHeight
    t = ((usableHeight - sumOfHeights) * @padding + Math.max(ySep, 0)) +  boundsForLayout.top()
    usableWidth = boundsForLayout.width() - Math.max(2*xSep,0)
    boundsBottom = boundsForLayout.bottom()
    boundsLeft = boundsForLayout.left()
    for i in [children.length-1 .. 0]
      m = @children[i]
      # major direction
      h = heights[i]
      # minor direction
      ls = m.layoutSpec
      w = Math.min(usableWidth, ls.widthFor(usableWidth))
      l = (usableWidth - w) * ls.minorDirectionPadding() + xSep + boundsLeft
      # Set bounds and adjust major direction for next step
      # self flag: #jmvVer2.
      # should extent be set in m's coordinate system? what if its scale is not 1?
      m.setPosition(new Point(l,t))
      m.setExtent(Math.min(w,boundsForLayout.height()),h)
      if h>0
        t = Math.min(t + h + ySep, boundsBottom)

  # So the user can adjust layout
  addAdjusterMorph: ->
    thickness = 4

    if @direction == "#horizontal"
      @addMorph( new LayoutAdjustingMorph() )
      @layoutSpec = LayoutSpec.fixedWidth(thickness)

    if @direction == "#vertical"
      @addMorph( new LayoutAdjustingMorph() )
      @layoutSpec = LayoutSpec.fixedHeight(thickness)

  #"Add a submorph, at the bottom or right, with aLayoutSpec"
  addMorphWithLayoutSpec: (aMorph, aLayoutSpec) ->
    aMorph.layoutSpec = aLayoutSpec
    @addMorph aMorph

  minPaneHeightForReframe: ->
    return 20

  minPaneWidthForReframe: ->
    return 40

  proportionalHeightNormalizationFactor: ->
    sumOfProportional = 0
    @children.forEach (child) =>
      if child.layoutSpec?
        sumOfProportional += child.layoutSpec.proportionalHeight()
    return 1.0/Math.max(sumOfProportional, 1.0)

  proportionalWidthNormalizationFactor: ->
    sumOfProportional = 0
    @children.forEach (child) =>
      if child.layoutSpec?
        sumOfProportional += child.layoutSpec.getProportionalWidth()
    return 1.0/Math.max(sumOfProportional, 1.0)

  adjustByAt: (aLayoutAdjustMorph, aPoint) ->
    if @direction == "#horizontal"
      @adjustHorizontallyByAt aLayoutAdjustMorph, aPoint

    if @direction == "#vertical"
      @adjustVerticallyByAt aLayoutAdjustMorph, aPoint

  adjustHorizontallyByAt: (aLayoutAdjustMorph, aPoint) ->
    # | delta l ls r rs lNewWidth rNewWidth i lCurrentWidth rCurrentWidth doNotResizeBelow |
    doNotResizeBelow =  @minPaneWidthForReframe
    i = @children[aLayoutAdjustMorph]
    l = @children[i+1]
    ls = l.layoutSpec
    lCurrentWidth = Math.max(l.morphWidth(),1) # avoid division by zero
    r = @children[i - 1]
    rs = r.layoutSpec
    rCurrentWidth = Math.max(r.morphWidth(),1) # avoid division by zero
    delta = aPoint.x - aLayoutAdjustMorph.position().x
    delta = Math.max(delta, doNotResizeBelow - lCurrentWidth)
    delta = Math.min(delta, rCurrentWidth - doNotResizeBelow)
    if delta == 0 then return @
    rNewWidth = rCurrentWidth - delta
    lNewWidth = lCurrentWidth + delta
    if ls.isProportionalWidth() and rs.isProportionalWidth()
      # If both proportional, update them
      ls.setProportionalWidth 1.0 * lNewWidth / lCurrentWidth * ls.proportionalWidth()
      rs.setProportionalWidth 1.0 * rNewWidth / rCurrentWidth * rs.proportionalWidth()
    else
      # If at least one is fixed, update only the fixed
      if !ls.isProportionalWidth()
          ls.fixedOrMorphWidth lNewWidth
      if !rs.isProportionalWidth()
          rs.fixedOrMorphWidth rNewWidth
    @layoutSubmorphs()

  adjustVerticallyByAt: (aLayoutAdjustMorph, aPoint) ->
    # | delta t ts b bs tNewHeight bNewHeight i tCurrentHeight bCurrentHeight doNotResizeBelow |
    doNotResizeBelow = @minPaneHeightForReframe()
    i = @children[aLayoutAdjustMorph]
    t = @children[i+1]
    ts = t.layoutSpec()
    tCurrentHeight = Math.max(t.morphHeight(),1) # avoid division by zero
    b = @children[i - 1]
    bs = b.layoutSpec
    bCurrentHeight = Math.max(b.morphHeight(),1) # avoid division by zero
    delta = aPoint.y - aLayoutAdjustMorph.position().y
    delta = Math.max(delta, doNotResizeBelow - tCurrentHeight)
    delta = Math.min(delta, bCurrentHeight - doNotResizeBelow)
    if delta == 0 then return @
    tNewHeight = tCurrentHeight + delta
    bNewHeight = bCurrentHeight - delta
    if ts.isProportionalHeight() and bs.isProportionalHeight()
      # If both proportional, update them
      ts.setProportionalHeight 1.0 * tNewHeight / tCurrentHeight * ts.proportionalHeight()
      bs.setProportionalHeight 1.0 * bNewHeight / bCurrentHeight * bs.proportionalHeight()
    else
      # If at least one is fixed, update only the fixed
      if !ts.isProportionalHeight()
          ts.fixedOrMorphHeight tNewHeight
      if !bs.isProportionalHeight()
          bs.fixedOrMorphHeight bNewHeight
    @layoutSubmorphs()

  #####################
  # convenience methods
  #####################

  addAdjusterAndMorphFixedHeight: (aMorph,aNumber) ->
    @addAdjusterAndMorphLayoutSpec(aMorph, LayoutSpec.newWithFixedHeight aNumber)

  addAdjusterAndMorphLayoutSpec: (aMorph, aLayoutSpec) ->
    #Add a submorph, at the bottom or right, with aLayoutSpec"
    @addAdjusterMorph()
    @addMorphLayoutSpec(aMorph, aLayoutSpec)

  addAdjusterAndMorphProportionalHeight: (aMorph, aNumber) ->
    @addAdjusterAndMorphLayoutSpec(aMorph, LayoutSpec.newWithProportionalHeight(aNumber))

  addAdjusterAndMorphProportionalWidth: (aMorph, aNumber) ->
    @addAdjusterAndMorphLayoutSpec(aMorph, LayoutSpec.newWithProportionalWidth(aNumber))

  addMorphFixedHeight: (aMorph, aNumber) ->
    @addMorphLayoutSpec(aMorph, LayoutSpec.newWithFixedHeight(aNumber))

  addMorphFixedWidth: (aMorph, aNumber) ->
    @addMorphLayoutSpec(aMorph, LayoutSpec.newWithFixedWidth(aNumber))

  addMorphLayoutSpec: (aMorph, aLayoutSpec) ->
    # Add a submorph, at the bottom or right, with aLayoutSpec
    aMorph.layoutSpec = aLayoutSpec
    @add aMorph

  addMorphProportionalHeight: (aMorph, aNumber) ->
    @addMorphLayoutSpec(aMorph, LayoutSpec.newWithProportionalHeight(aNumber))

  addMorphProportionalWidth: (aMorph, aNumber) ->
    @addMorphLayoutSpec(aMorph, LayoutSpec.newWithProportionalWidth(aNumber))

  addMorphUseAll: (aMorph) ->
    @addMorphLayoutSpec(aMorph, LayoutSpec.useAll())

  addMorphs: (morphs) ->
    morphs.forEach (morph) =>
      @addMorphProportionalWidth(m,1)

  addMorphsWidthProportionalTo: (morphs, widths) ->
    morphs.forEach (morph) =>
      @addMorphProportionalWidth(m,w)

  # unclear how to translate this one for the time being
  is: (aSymbol) ->
    return aSymbol == "#LayoutMorph" # or [ super is: aSymbol ]

  @test1: ->
    rect1 = new RectangleMorph(new Point(20,20), new Color(255,0,0));
    rect2 = new RectangleMorph(new Point(20,20), new Color(0,255,0));
    row = LayoutMorph.newRow()
    row.addMorphProportionalWidth(rect1,2)
    row.addMorphProportionalWidth(rect2,1)
    row.layoutSubmorphs()
    row.setPosition(world.hand.position());
    row.keepWithin(world);
    world.add(row);
    row.changed();

    # attach a HandleMorph to it so that
    # we can check how it resizes
    handle = new HandleMorph()
    handle.isDraggable = false
    handle.target = row
    handle.updateRendering()
    handle.noticesTransparentClick = true

  @test2: ->
    rect3 = new RectangleMorph(new Point(20,20), new Color(255,0,0));
    rect4 = new RectangleMorph(new Point(20,20), new Color(0,255,0));
    row2 = LayoutMorph.newRow()
    row2.addMorphFixedWidth(rect3,10)
    row2.addMorphProportionalWidth(rect4,1)
    row2.layoutSubmorphs()
    row2.setPosition(world.hand.position());
    row2.keepWithin(world);
    world.add(row2);
    row2.changed();

    # attach a HandleMorph to it so that
    # we can check how it resizes
    handle = new HandleMorph()
    handle.isDraggable = false
    handle.target = row2
    handle.updateRendering()
    handle.noticesTransparentClick = true

  @test3: ->
    rect5 = new RectangleMorph(new Point(20,20), new Color(255,0,0));
    rect6 = new RectangleMorph(new Point(20,20), new Color(0,255,0));
    rect7 = new RectangleMorph(new Point(20,20), new Color(0,0,255));
    row3 = LayoutMorph.newRow()
    row3.addMorphProportionalWidth(rect6,2)
    row3.addMorphFixedWidth(rect5,10)
    row3.addMorphProportionalWidth(rect7,1)
    row3.layoutSubmorphs()
    row3.setPosition(world.hand.position());
    row3.keepWithin(world);
    world.add(row3);
    row3.changed();

    # attach a HandleMorph to it so that
    # we can check how it resizes
    handle = new HandleMorph()
    handle.isDraggable = false
    handle.target = row3
    handle.updateRendering()
    handle.noticesTransparentClick = true

  @test4: ->
    # //////////////////////////////////////////////////
    # note how the vertical spacing in the horizontal layout
    # is different. the vertical size is not adjusted considering
    # all other morphs. A proportional of 1.1 is proportional to the
    # container, not to the other layouts.
    # Equivalent smalltalk code:
    # | pane rect1 rect2 |
    # pane _ LayoutMorph newRow separation: 5. "3"
    # pane addMorph: (StringMorph contents: '3').
    # 
    # rect1 := BorderedRectMorph new color: (Color lightOrange).
    # pane addMorph: rect1 
    #          layoutSpec: (LayoutSpec  fixedWidth: 20 proportionalHeight: 1.1 minorDirectionPadding: #center).
    # rect2 := BorderedRectMorph new color: (Color cyan);
    #   layoutSpec: (LayoutSpec  fixedWidth: 20 proportionalHeight: 0.5 minorDirectionPadding: #center).
    # pane addMorph: rect2.
    # pane
    #   color: Color lightGreen;
    #   openInWorld;
    #   morphPosition: 520 @ 50;
    #   morphExtent: 180 @ 100
    # //////////////////////////////////////////////////

    rect5 = new RectangleMorph(new Point(20,20), new Color(255,0,0));
    rect6 = new RectangleMorph(new Point(20,20), new Color(0,255,0));
    rect7 = new RectangleMorph(new Point(20,20), new Color(0,0,255));
    row3 = LayoutMorph.newRow()
    row3.addMorphProportionalHeight(rect6,0.5)
    row3.addMorphFixedHeight(rect5,200)
    row3.addMorphProportionalHeight(rect7,1.1)
    row3.layoutSubmorphs()
    row3.setPosition(world.hand.position());
    row3.keepWithin(world);
    world.add(row3);
    row3.changed();

    # attach a HandleMorph to it so that
    # we can check how it resizes
    handle = new HandleMorph()
    handle.isDraggable = false
    handle.target = row3
    handle.updateRendering()
    handle.noticesTransparentClick = true #
  '''

# LayoutSpec

# this comment below is needed to figure our dependencies between classes

# This is a port of the
# respective Cuis Smalltalk classes (version 4.2-1766)
# Cuis is by Juan Vuletich

# LayoutSpecs are the basis for the layout mechanism.
# Any Morph can be given a LayoutSpec, but in order to honor it,
# its owner must be a LayoutMorph.

# A LayoutSpec specifies how a morph wants to be layed out.
# It can specify either a fixed width or a fraction of some
# available owner width. Same goes for height. If a fraction
# is specified, a minimum extent is also possible.


# Alternatives:
#  - proportionalWidth notNil, fixedWidth notNil ->    Use fraction of available space, take fixedWidth as minimum desired width
#  - proportionalWidth isNil, fixedWidth isNil   ->    Use current morph width
#  - proportionalWidth isNil, fixedWidth notNil    ->    Use fixedWidth
#  - proportionalWidth notNil, fixedWidth isNil    ->    NOT VALID

#Same goes for proportionalHeight and fixedHeight

class LayoutSpec

  morph: null
  minorDirectionPadding: 0.5
  fixedWidth: 0
  fixedHeight: 0
  proportionalWidth: 1.0
  proportionalHeight: 1.0


  # Just some reasonable defaults, use all available space
  constructor: ->

  @newWithFixedExtent: (aPoint) ->
    @newWithFixedWidthFixedHeight(aPoint.x, aPoint.y)

  @newWithFixedHeight: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedHeight aNumber
   return layoutSpec

  @newWithFixedWidth: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedWidth aNumber
   return layoutSpec

  @newWithFixedWidthFixedHeight: (aNumber, otherNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedWidth aNumber
   layoutSpec.setFixedHeight otherNumber
   return layoutSpec

  @newWithFixedWidthFixedHeightMinorDirectionPadding: (aNumber, otherNumber, aSymbolOrNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedWidth aNumber
   layoutSpec.setFixedHeight otherNumber
   layoutSpec.setMinorDirectionPadding aSymbolOrNumber
   return layoutSpec

  @newWithFixedWidthProportionalHeight: (aNumber, otherNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedWidth aNumber
   layoutSpec.setProportionalHeight otherNumber
   return layoutSpec

  @newWithFixedWidthProportionalHeightMinorDirectionPadding: (aNumber, otherNumber, aSymbolOrNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedWidth aNumber
   layoutSpec.setProportionalHeight otherNumber
   layoutSpec.setMinorDirectionPadding aSymbolOrNumber
   return layoutSpec

  @newWithKeepMorphExtent: ->
   layoutSpec = new @()
   layoutSpec.useMorphWidth
   layoutSpec.useMorphHeight
   return layoutSpec

  @newWithMorphHeightFixedWidth: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedWidth aNumber
   layoutSpec.useMorphHeight
   return layoutSpec

  @newWithMorphHeightProportionalWidth: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalWidth aNumber
   layoutSpec.useMorphHeight()
   return layoutSpec

  @newWithMorphWidthFixedHeight: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.useMorphWidth()
   layoutSpec.setFixedHeight aNumber
   return layoutSpec

  @newWithMorphWidthProportionalHeight: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.useMorphWidth()
   layoutSpec.setProportionalHeight aNumber
   return layoutSpec

  # Will use all available width
  @newWithProportionalHeight: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalHeight aNumber
   return layoutSpec

  # Will use all available height
  @newWithProportionalWidth: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalWidth aNumber
   return layoutSpec

  @newWithProportionalWidthFixedHeight: (aNumber, otherNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalWidth aNumber
   layoutSpec.setFixedHeight otherNumber
   return layoutSpec

  @newWithProportionalWidthFixedHeightMinorDirectionPadding: (aNumber, otherNumber, aSymbolOrNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalWidth aNumber
   layoutSpec.setFixedHeight otherNumber
   layoutSpec.setMinorDirectionPadding aSymbolOrNumber
   return layoutSpec

  @newWithProportionalWidthProportionalHeight: (aNumber, otherNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalWidth aNumber
   layoutSpec.setProportionalHeight otherNumber
   return layoutSpec

  @newWithProportionalWidthProportionalHeightMinorDirectionPadding: (aNumber, otherNumber, aSymbolOrNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalWidth aNumber
   layoutSpec.setProportionalHeight otherNumber
   layoutSpec.setMinorDirectionPadding aSymbolOrNumber
   return layoutSpec

  # Use all available space
  @newWithUseAll: ->
   return new @()

  setFixedHeight: (aNumber) ->
   # aNumber is taken as the fixed height to use.
   # No proportional part.
   @fixedHeight = aNumber
   @proportionalHeight = null

  setFixedOrMorphHeight: (aNumber) ->
    # aNumber is taken as the fixed height to use.
    # No proportional part.
    if fixedHeight?
      @fixedHeight = aNumber
    else
      @morph.setHeight aNumber
    @proportionalHeight = null

  setFixedOrMorphWidth: (aNumber) ->
    # aNumber is taken as the fixed width to use.
    # No proportional part.
    if fixedWidth?
      @fixedWidth = aNumber
    else
      @morph.setWidth aNumber
    @proportionalWidth = null

  setFixedWidth: (aNumber) ->
    # aNumber is taken as the fixed width to use.
    # No proportional part.
    @fixedWidth = aNumber
    @proportionalWidth = null

  setMinorDirectionPadding: (howMuchPadding) ->
    # This sets how padding is done in the secondary direction.
    # For instance, if the owning morph is set in a row,
    # the row will control horizontal layout. But if there
    # is unused vertical space, it will be used according to
    # this parameter. For instance, #top sets the owning morph
    # at the top. Same for #bottom and #center. If the owner is
    # contained in a column, #left, #center or #right should be
    # used. Alternatively, any number between 0.0 and 1.0 can be
    # used.
    #  self new minorDirectionPadding: #center
    #  self new minorDirectionPadding: 0.9

    switch howMuchPadding
      when "#top" then @minorDirectionPadding = 0.0
      when "#left" then @minorDirectionPadding = 0.0
      when "#center" then @minorDirectionPadding = 0.5
      when "#right" then @minorDirectionPadding = 1.0
      when "#bottom" then @minorDirectionPadding = 1.0
      else @minorDirectionPadding = howMuchPadding

  setProportionalHeight: (aNumber) ->
   @setProportionalHeightMinimum(aNumber, 0.0)

  setProportionalHeightMinimum: (aNumberOrNil, otherNumberOrNil) ->
    # Alternatives: same as in #proportionalWidth:minimum:
    # see comment there
    @proportionalHeight = aNumberOrNil
    @fixedHeight = otherNumberOrNil

  setProportionalWidth: (aNumber) ->
    return @setProportionalWidthMinimum aNumber, 0

  setProportionalWidthMinimum: (aNumberOrNil, otherNumberOrNil) ->
    # Alternatives:
    #  - proportionalWidth notNil, fixedWidth notNil ->    Use fraction of available space, take fixedWidth as minimum desired width
    #  - proportionalWidth isNil, fixedWidth isNil   ->    Use current morph width
    #  - proportionalWidth isNil, fixedWidth notNil  ->    Use fixedWidth
    #  - proportionalWidth notNil, fixedWidth isNil  ->    NOT VALID
    @proportionalWidth = aNumberOrNil
    @fixedWidth = otherNumberOrNil

  setProportionalHeight: (aNumberOrNil) ->
   # Alternatives: same as in #proportionalWidth:minimum:, see comment there
   @proportionalHeight = aNumberOrNil

  setProportionalWidth: (aNumberOrNil) ->
    # Alternatives:
    #  - proportionalWidth notNil, fixedWidth notNil ->    Use fraction of available space, take fixedWidth as minimum desired width
    #  - proportionalWidth isNil, fixedWidth isNil   ->    Use current morph width
    #  - proportionalWidth isNil, fixedWidth notNil  ->    Use fixedWidth
    #  - proportionalWidth notNil, fixedWidth isNil  ->    NOT VALID"
    @proportionalWidth = aNumberOrNil

  useMorphHeight: ->
    # Do not attempt to layout height. Use current morph height if at all possible
    @fixedHeight = null
    @proportionalHeight = null

  useMorphWidth: ->
    # Do not attempt to layout width. Use current morph width if at all possible
    @fixedWidth = null
    @proportionalWidth = null

  getFixedHeight: ->
    # If proportional is zero, answer stored fixed extent,
    # or actual morph extent if undefined. (no proportional extent is computed)
    # Otherwise, we do proportional layout, and the stored extent is
    # a minimum extent, so we don't  really a fixed extent.
    if @proportionalHeight?
      return 0
    if not @fixedHeight?
      return @morph.height()

  getFixedWidth: ->
    # If proportional is zero, answer stored fixed extent,
    # or actual morph extent if undefined. (no proportional extent is computed)
    # Otherwise, we do proportional layout, and the stored extent is
    # a minimum extent, so we don't  really a fixed extent.
    if @proportionalWidth?
      return 0
    if not @fixedWidth?
      return @morph.width()

  heightFor: (availableSpace) ->
    # If proportional is zero, answer stored fixed extent,
    # or actual morph extent if undefined.
    # Otherwise, we do proportional layout, and the stored
    # extent is a minimum extent.
    # If there is no minimum extent, it should be set to zero.

    if @proportionalHeight?
      return Math.max( @fixedHeight, Math.round(@proportionalHeight * availableSpace) )
    return @getFixedHeight()

  getFixedHeight: ->
    if not @fixedHeight?
      return 0
    else
      @fixedHeight

  getFixedWidth: ->
    if not @fixedWidth?
      return 0
    else
      @fixedWidth

  getProportionalHeight: ->
    if not @proportionalHeight?
      return 0
    else
      @proportionalHeight

  getProportionalWidth: ->
    if not @proportionalWidth?
      return 0
    else
      @proportionalWidth

  widthFor: (availableSpace) ->
    # If proportional is zero, answer stored fixed extent,
    # or actual morph extent if undefined.
    # Otherwise, we do proportional layout, and the
    # stored extent is a minimum extent.
    # If there is no minimum extent, it should be set to zero.
    if @proportionalWidth?
      return Math.max( @fixedWidth, Math.round(@proportionalWidth * availableSpace) )
    return @getFixedWidth()

  isProportionalHeight: ->
    return @proportionalHeight?

  isProportionalWidth: ->
    return @proportionalWidth?
  @coffeeScriptSourceOfThisClass: '''
# LayoutSpec

# this comment below is needed to figure our dependencies between classes

# This is a port of the
# respective Cuis Smalltalk classes (version 4.2-1766)
# Cuis is by Juan Vuletich

# LayoutSpecs are the basis for the layout mechanism.
# Any Morph can be given a LayoutSpec, but in order to honor it,
# its owner must be a LayoutMorph.

# A LayoutSpec specifies how a morph wants to be layed out.
# It can specify either a fixed width or a fraction of some
# available owner width. Same goes for height. If a fraction
# is specified, a minimum extent is also possible.


# Alternatives:
#  - proportionalWidth notNil, fixedWidth notNil ->    Use fraction of available space, take fixedWidth as minimum desired width
#  - proportionalWidth isNil, fixedWidth isNil   ->    Use current morph width
#  - proportionalWidth isNil, fixedWidth notNil    ->    Use fixedWidth
#  - proportionalWidth notNil, fixedWidth isNil    ->    NOT VALID

#Same goes for proportionalHeight and fixedHeight

class LayoutSpec

  morph: null
  minorDirectionPadding: 0.5
  fixedWidth: 0
  fixedHeight: 0
  proportionalWidth: 1.0
  proportionalHeight: 1.0


  # Just some reasonable defaults, use all available space
  constructor: ->

  @newWithFixedExtent: (aPoint) ->
    @newWithFixedWidthFixedHeight(aPoint.x, aPoint.y)

  @newWithFixedHeight: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedHeight aNumber
   return layoutSpec

  @newWithFixedWidth: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedWidth aNumber
   return layoutSpec

  @newWithFixedWidthFixedHeight: (aNumber, otherNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedWidth aNumber
   layoutSpec.setFixedHeight otherNumber
   return layoutSpec

  @newWithFixedWidthFixedHeightMinorDirectionPadding: (aNumber, otherNumber, aSymbolOrNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedWidth aNumber
   layoutSpec.setFixedHeight otherNumber
   layoutSpec.setMinorDirectionPadding aSymbolOrNumber
   return layoutSpec

  @newWithFixedWidthProportionalHeight: (aNumber, otherNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedWidth aNumber
   layoutSpec.setProportionalHeight otherNumber
   return layoutSpec

  @newWithFixedWidthProportionalHeightMinorDirectionPadding: (aNumber, otherNumber, aSymbolOrNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedWidth aNumber
   layoutSpec.setProportionalHeight otherNumber
   layoutSpec.setMinorDirectionPadding aSymbolOrNumber
   return layoutSpec

  @newWithKeepMorphExtent: ->
   layoutSpec = new @()
   layoutSpec.useMorphWidth
   layoutSpec.useMorphHeight
   return layoutSpec

  @newWithMorphHeightFixedWidth: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.setFixedWidth aNumber
   layoutSpec.useMorphHeight
   return layoutSpec

  @newWithMorphHeightProportionalWidth: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalWidth aNumber
   layoutSpec.useMorphHeight()
   return layoutSpec

  @newWithMorphWidthFixedHeight: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.useMorphWidth()
   layoutSpec.setFixedHeight aNumber
   return layoutSpec

  @newWithMorphWidthProportionalHeight: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.useMorphWidth()
   layoutSpec.setProportionalHeight aNumber
   return layoutSpec

  # Will use all available width
  @newWithProportionalHeight: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalHeight aNumber
   return layoutSpec

  # Will use all available height
  @newWithProportionalWidth: (aNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalWidth aNumber
   return layoutSpec

  @newWithProportionalWidthFixedHeight: (aNumber, otherNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalWidth aNumber
   layoutSpec.setFixedHeight otherNumber
   return layoutSpec

  @newWithProportionalWidthFixedHeightMinorDirectionPadding: (aNumber, otherNumber, aSymbolOrNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalWidth aNumber
   layoutSpec.setFixedHeight otherNumber
   layoutSpec.setMinorDirectionPadding aSymbolOrNumber
   return layoutSpec

  @newWithProportionalWidthProportionalHeight: (aNumber, otherNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalWidth aNumber
   layoutSpec.setProportionalHeight otherNumber
   return layoutSpec

  @newWithProportionalWidthProportionalHeightMinorDirectionPadding: (aNumber, otherNumber, aSymbolOrNumber) ->
   layoutSpec = new @()
   layoutSpec.setProportionalWidth aNumber
   layoutSpec.setProportionalHeight otherNumber
   layoutSpec.setMinorDirectionPadding aSymbolOrNumber
   return layoutSpec

  # Use all available space
  @newWithUseAll: ->
   return new @()

  setFixedHeight: (aNumber) ->
   # aNumber is taken as the fixed height to use.
   # No proportional part.
   @fixedHeight = aNumber
   @proportionalHeight = null

  setFixedOrMorphHeight: (aNumber) ->
    # aNumber is taken as the fixed height to use.
    # No proportional part.
    if fixedHeight?
      @fixedHeight = aNumber
    else
      @morph.setHeight aNumber
    @proportionalHeight = null

  setFixedOrMorphWidth: (aNumber) ->
    # aNumber is taken as the fixed width to use.
    # No proportional part.
    if fixedWidth?
      @fixedWidth = aNumber
    else
      @morph.setWidth aNumber
    @proportionalWidth = null

  setFixedWidth: (aNumber) ->
    # aNumber is taken as the fixed width to use.
    # No proportional part.
    @fixedWidth = aNumber
    @proportionalWidth = null

  setMinorDirectionPadding: (howMuchPadding) ->
    # This sets how padding is done in the secondary direction.
    # For instance, if the owning morph is set in a row,
    # the row will control horizontal layout. But if there
    # is unused vertical space, it will be used according to
    # this parameter. For instance, #top sets the owning morph
    # at the top. Same for #bottom and #center. If the owner is
    # contained in a column, #left, #center or #right should be
    # used. Alternatively, any number between 0.0 and 1.0 can be
    # used.
    #  self new minorDirectionPadding: #center
    #  self new minorDirectionPadding: 0.9

    switch howMuchPadding
      when "#top" then @minorDirectionPadding = 0.0
      when "#left" then @minorDirectionPadding = 0.0
      when "#center" then @minorDirectionPadding = 0.5
      when "#right" then @minorDirectionPadding = 1.0
      when "#bottom" then @minorDirectionPadding = 1.0
      else @minorDirectionPadding = howMuchPadding

  setProportionalHeight: (aNumber) ->
   @setProportionalHeightMinimum(aNumber, 0.0)

  setProportionalHeightMinimum: (aNumberOrNil, otherNumberOrNil) ->
    # Alternatives: same as in #proportionalWidth:minimum:
    # see comment there
    @proportionalHeight = aNumberOrNil
    @fixedHeight = otherNumberOrNil

  setProportionalWidth: (aNumber) ->
    return @setProportionalWidthMinimum aNumber, 0

  setProportionalWidthMinimum: (aNumberOrNil, otherNumberOrNil) ->
    # Alternatives:
    #  - proportionalWidth notNil, fixedWidth notNil ->    Use fraction of available space, take fixedWidth as minimum desired width
    #  - proportionalWidth isNil, fixedWidth isNil   ->    Use current morph width
    #  - proportionalWidth isNil, fixedWidth notNil  ->    Use fixedWidth
    #  - proportionalWidth notNil, fixedWidth isNil  ->    NOT VALID
    @proportionalWidth = aNumberOrNil
    @fixedWidth = otherNumberOrNil

  setProportionalHeight: (aNumberOrNil) ->
   # Alternatives: same as in #proportionalWidth:minimum:, see comment there
   @proportionalHeight = aNumberOrNil

  setProportionalWidth: (aNumberOrNil) ->
    # Alternatives:
    #  - proportionalWidth notNil, fixedWidth notNil ->    Use fraction of available space, take fixedWidth as minimum desired width
    #  - proportionalWidth isNil, fixedWidth isNil   ->    Use current morph width
    #  - proportionalWidth isNil, fixedWidth notNil  ->    Use fixedWidth
    #  - proportionalWidth notNil, fixedWidth isNil  ->    NOT VALID"
    @proportionalWidth = aNumberOrNil

  useMorphHeight: ->
    # Do not attempt to layout height. Use current morph height if at all possible
    @fixedHeight = null
    @proportionalHeight = null

  useMorphWidth: ->
    # Do not attempt to layout width. Use current morph width if at all possible
    @fixedWidth = null
    @proportionalWidth = null

  getFixedHeight: ->
    # If proportional is zero, answer stored fixed extent,
    # or actual morph extent if undefined. (no proportional extent is computed)
    # Otherwise, we do proportional layout, and the stored extent is
    # a minimum extent, so we don't  really a fixed extent.
    if @proportionalHeight?
      return 0
    if not @fixedHeight?
      return @morph.height()

  getFixedWidth: ->
    # If proportional is zero, answer stored fixed extent,
    # or actual morph extent if undefined. (no proportional extent is computed)
    # Otherwise, we do proportional layout, and the stored extent is
    # a minimum extent, so we don't  really a fixed extent.
    if @proportionalWidth?
      return 0
    if not @fixedWidth?
      return @morph.width()

  heightFor: (availableSpace) ->
    # If proportional is zero, answer stored fixed extent,
    # or actual morph extent if undefined.
    # Otherwise, we do proportional layout, and the stored
    # extent is a minimum extent.
    # If there is no minimum extent, it should be set to zero.

    if @proportionalHeight?
      return Math.max( @fixedHeight, Math.round(@proportionalHeight * availableSpace) )
    return @getFixedHeight()

  getFixedHeight: ->
    if not @fixedHeight?
      return 0
    else
      @fixedHeight

  getFixedWidth: ->
    if not @fixedWidth?
      return 0
    else
      @fixedWidth

  getProportionalHeight: ->
    if not @proportionalHeight?
      return 0
    else
      @proportionalHeight

  getProportionalWidth: ->
    if not @proportionalWidth?
      return 0
    else
      @proportionalWidth

  widthFor: (availableSpace) ->
    # If proportional is zero, answer stored fixed extent,
    # or actual morph extent if undefined.
    # Otherwise, we do proportional layout, and the
    # stored extent is a minimum extent.
    # If there is no minimum extent, it should be set to zero.
    if @proportionalWidth?
      return Math.max( @fixedWidth, Math.round(@proportionalWidth * availableSpace) )
    return @getFixedWidth()

  isProportionalHeight: ->
    return @proportionalHeight?

  isProportionalWidth: ->
    return @proportionalWidth?  '''

# ScrollFrameMorph ////////////////////////////////////////////////////

# this comment below is needed to figure our dependencies between classes
# REQUIRES globalFunctions

class ScrollFrameMorph extends FrameMorph

  autoScrollTrigger: null
  hasVelocity: true # dto.
  padding: 0 # around the scrollable area
  growth: 0 # pixels or Point to grow right/left when near edge
  isTextLineWrapping: false
  isScrollingByDragging: true
  scrollBarSize: null
  contents: null
  vBar: null
  hBar: null

  constructor: (@contents, scrollBarSize, @sliderColor) ->
    # super() paints the scrollframe, which we don't want,
    # so we set 0 opacity here.
    @alpha = 0
    super()
    @scrollBarSize = scrollBarSize or WorldMorph.preferencesAndSettings.scrollBarSize

    @contents = new FrameMorph(@) unless @contents?
    @add @contents

    # the scrollFrame is never going to paint itself,
    # but its values are going to mimick the values of the
    # contained frame
    @color = @contents.color
    @alpha = @contents.alpha
    
    #@setColor = @contents.setColor
    #@setAlphaScaled = @contents.setAlphaScaled

    @hBar = new SliderMorph(null, null, null, null, "horizontal", @sliderColor)
    @hBar.setHeight @scrollBarSize

    @hBar.isDraggable = false
    @hBar.target = @
    @add @hBar

    @vBar = new SliderMorph(null, null, null, null, "vertical", @sliderColor)
    @vBar.setWidth @scrollBarSize
    @vBar.isDraggable = false
    @vBar.target = @
    @add @vBar

    @hBar.action = (num, target) =>
      target.contents.setPosition new Point(target.left() - num, target.contents.position().y)
      target.contents.adjustBounds()
    @vBar.action = (num, target) =>
      target.contents.setPosition new Point(target.contents.position().x, target.top() - num)
      target.contents.adjustBounds()
    @adjustScrollBars()

  setColor: (aColor) ->
    # update the color of the scrollFrame - note
    # that we are never going to paint the scrollFrame
    # we are updating the color so that its value is the same as the
    # contained frame
    @color = aColor
    @contents.setColor(aColor)

  setAlphaScaled: (alpha) ->
    # update the alpha of the scrollFrame - note
    # that we are never going to paint the scrollFrame
    # we are updating the alpha so that its value is the same as the
    # contained frame
    @alpha = @calculateAlphaScaled(alpha)
    @contents.setAlphaScaled(alpha)

  adjustScrollBars: ->
    hWidth = @width() - @scrollBarSize
    vHeight = @height() - @scrollBarSize
    @changed()

    # this check is to see whether the bar actually belongs to this
    # scrollframe. The reason why the bar could belong to another
    # scrollframe is the following: the bar could have been detached
    # from a scrollframe A. The scrollframe A (which is still fully
    # working albeit detached) is then duplicated into
    # a scrollframe B. What happens is that because the bar is not
    # a child of A (rather, it's only referenced as a property),
    # the duplication mechanism does not duplicate the bar and it does
    # not update the reference to it. This is correct because one cannot
    # just change all the references to other objects that are not children
    # , a good example being the targets, i.e. if you duplicate a colorPicker
    # which targets a Morph you want the duplication of the colorPicker to
    # still change color of that same Morph.
    # So: the scrollframe B could still reference the scrollbar
    # detached from A and that causes a problem because changes to B would
    # change the dimensions and hiding/unhiding of the scrollbar.
    # So here we avoid that by actually checking what the scrollbar is
    # attached to.
    if @hBar.target == @ 
      if @contents.width() >= @width() + 1
        @hBar.show()
        @hBar.setWidth hWidth  if @hBar.width() isnt hWidth
        # we check whether the bar has been detached. If it's still
        # attached then we possibly move it, together with the
        # scrollframe, otherwise we don't move it.
        if @hBar.parent == @
          @hBar.setPosition new Point(@left(), @bottom() - @hBar.height())
        @hBar.start = 0
        @hBar.stop = @contents.width() - @width()
        @hBar.size = @width() / @contents.width() * @hBar.stop
        @hBar.value = @left() - @contents.left()
        @hBar.updateRendering()
      else
        @hBar.hide()

    # see comment on equivalent if line above.
    if @vBar.target == @ 
      if @contents.height() >= @height() + 1
        @vBar.show()
        @vBar.setHeight vHeight  if @vBar.height() isnt vHeight
        # we check whether the bar has been detached. If it's still
        # attached then we possibly move it, together with the
        # scrollframe, otherwise we don't move it.
        if @vBar.parent == @
          @vBar.setPosition new Point(@right() - @vBar.width(), @top())
        @vBar.start = 0
        @vBar.stop = @contents.height() - @height()
        @vBar.size = @height() / @contents.height() * @vBar.stop
        @vBar.value = @top() - @contents.top()
        @vBar.updateRendering()
      else
        @vBar.hide()
  
  addContents: (aMorph) ->
    @contents.add aMorph
    @contents.adjustBounds()
    @adjustScrollBars()
  
  setContents: (aMorph, extraPadding) ->
    @extraPadding = extraPadding
    @contents.destroyAll()
    #
    @contents.children = []
    aMorph.setPosition @position().add(@padding + @extraPadding)
    @addContents aMorph
  
  setExtent: (aPoint) ->
    @contents.setPosition @position().copy()  if @isTextLineWrapping
    super aPoint
    @contents.adjustBounds()
    @adjustScrollBars()
  
  # ScrollFrameMorph scrolling by dragging:
  scrollX: (steps) ->
    cl = @contents.left()
    l = @left()
    cw = @contents.width()
    r = @right()
    newX = cl + steps
    newX = r - cw  if newX + cw < r
    newX = l  if newX > l
    @contents.setLeft newX  if newX isnt cl
  
  scrollY: (steps) ->
    ct = @contents.top()
    t = @top()
    ch = @contents.height()
    b = @bottom()
    newY = ct + steps
    if newY + ch < b
      newY = b - ch
    # prevents content to be scrolled to the frame's
    # bottom if the content is otherwise empty
    newY = t  if newY > t
    @contents.setTop newY  if newY isnt ct
  
  mouseDownLeft: (pos) ->
    return null  unless @isScrollingByDragging
    world = @root()
    oldPos = pos
    deltaX = 0
    deltaY = 0
    friction = 0.8
    @step = =>
      if world.hand.mouseButton and
        (!world.hand.children.length) and
        (@bounds.containsPoint(world.hand.position()))
          newPos = world.hand.bounds.origin
          if @hBar.isVisible
            deltaX = newPos.x - oldPos.x
            @scrollX deltaX  if deltaX isnt 0
          if @vBar.isVisible
            deltaY = newPos.y - oldPos.y
            @scrollY deltaY  if deltaY isnt 0
          oldPos = newPos
      else
        unless @hasVelocity
          @step = noOperation
        else
          if (Math.abs(deltaX) < 0.5) and (Math.abs(deltaY) < 0.5)
            @step = noOperation
          else
            if @hBar.isVisible
              deltaX = deltaX * friction
              @scrollX Math.round(deltaX)
            if @vBar.isVisible
              deltaY = deltaY * friction
              @scrollY Math.round(deltaY)
      console.log "adjusting..."
      @contents.adjustBounds()
      @adjustScrollBars()
  
  startAutoScrolling: ->
    inset = WorldMorph.preferencesAndSettings.scrollBarSize * 3
    world = @world()
    return null  unless world
    hand = world.hand
    @autoScrollTrigger = Date.now()  unless @autoScrollTrigger
    @step = =>
      pos = hand.bounds.origin
      inner = @bounds.insetBy(inset)
      if (@bounds.containsPoint(pos)) and
        (not (inner.containsPoint(pos))) and
        (hand.children.length)
          @autoScroll pos
      else
        @step = noOperation
        @autoScrollTrigger = null
  
  autoScroll: (pos) ->
    return null  if Date.now() - @autoScrollTrigger < 500
    inset = WorldMorph.preferencesAndSettings.scrollBarSize * 3
    area = @topLeft().extent(new Point(@width(), inset))
    @scrollY inset - (pos.y - @top())  if area.containsPoint(pos)
    area = @topLeft().extent(new Point(inset, @height()))
    @scrollX inset - (pos.x - @left())  if area.containsPoint(pos)
    area = (new Point(@right() - inset, @top())).extent(new Point(inset, @height()))
    @scrollX -(inset - (@right() - pos.x))  if area.containsPoint(pos)
    area = (new Point(@left(), @bottom() - inset)).extent(new Point(@width(), inset))
    @scrollY -(inset - (@bottom() - pos.y))  if area.containsPoint(pos)
    @contents.adjustBounds()
    @adjustScrollBars()  
  
  # ScrollFrameMorph scrolling when editing text
  # so to bring the caret fully into view.
  scrollCaretIntoView: (caretMorph) ->
    txt = caretMorph.target
    offset = txt.position().subtract(@contents.position())
    ft = @top() + @padding
    fb = @bottom() - @padding
    fl = @left() + @padding
    fr = @right() - @padding
    @contents.adjustBounds()
    if caretMorph.top() < ft
      @contents.setTop @contents.top() + ft - caretMorph.top()
      caretMorph.setTop ft
    else if caretMorph.bottom() > fb
      @contents.setBottom @contents.bottom() + fb - caretMorph.bottom()
      caretMorph.setBottom fb
    if caretMorph.left() < fl
      @contents.setLeft @contents.left() + fl - caretMorph.left()
      caretMorph.setLeft fl
    else if caretMorph.right() > fr
      @contents.setRight @contents.right() + fr - caretMorph.right()
      caretMorph.setRight fr
    @contents.adjustBounds()
    @adjustScrollBars()

  # ScrollFrameMorph events:
  mouseScroll: (y, x) ->
    @scrollY y * WorldMorph.preferencesAndSettings.mouseScrollAmount  if y
    @scrollX x * WorldMorph.preferencesAndSettings.mouseScrollAmount  if x
    @contents.adjustBounds()
    @adjustScrollBars()
  
  
  developersMenu: ->
    menu = super()
    if @isTextLineWrapping
      menu.addItem "auto line wrap off...", (->@toggleTextLineWrapping()), "turn automatic\nline wrapping\noff"
    else
      menu.addItem "auto line wrap on...", (->@toggleTextLineWrapping()), "enable automatic\nline wrapping"
    menu
  
  toggleTextLineWrapping: ->
    @isTextLineWrapping = not @isTextLineWrapping

  @coffeeScriptSourceOfThisClass: '''
# ScrollFrameMorph ////////////////////////////////////////////////////

# this comment below is needed to figure our dependencies between classes
# REQUIRES globalFunctions

class ScrollFrameMorph extends FrameMorph

  autoScrollTrigger: null
  hasVelocity: true # dto.
  padding: 0 # around the scrollable area
  growth: 0 # pixels or Point to grow right/left when near edge
  isTextLineWrapping: false
  isScrollingByDragging: true
  scrollBarSize: null
  contents: null
  vBar: null
  hBar: null

  constructor: (@contents, scrollBarSize, @sliderColor) ->
    # super() paints the scrollframe, which we don't want,
    # so we set 0 opacity here.
    @alpha = 0
    super()
    @scrollBarSize = scrollBarSize or WorldMorph.preferencesAndSettings.scrollBarSize

    @contents = new FrameMorph(@) unless @contents?
    @add @contents

    # the scrollFrame is never going to paint itself,
    # but its values are going to mimick the values of the
    # contained frame
    @color = @contents.color
    @alpha = @contents.alpha
    
    #@setColor = @contents.setColor
    #@setAlphaScaled = @contents.setAlphaScaled

    @hBar = new SliderMorph(null, null, null, null, "horizontal", @sliderColor)
    @hBar.setHeight @scrollBarSize

    @hBar.isDraggable = false
    @hBar.target = @
    @add @hBar

    @vBar = new SliderMorph(null, null, null, null, "vertical", @sliderColor)
    @vBar.setWidth @scrollBarSize
    @vBar.isDraggable = false
    @vBar.target = @
    @add @vBar

    @hBar.action = (num, target) =>
      target.contents.setPosition new Point(target.left() - num, target.contents.position().y)
      target.contents.adjustBounds()
    @vBar.action = (num, target) =>
      target.contents.setPosition new Point(target.contents.position().x, target.top() - num)
      target.contents.adjustBounds()
    @adjustScrollBars()

  setColor: (aColor) ->
    # update the color of the scrollFrame - note
    # that we are never going to paint the scrollFrame
    # we are updating the color so that its value is the same as the
    # contained frame
    @color = aColor
    @contents.setColor(aColor)

  setAlphaScaled: (alpha) ->
    # update the alpha of the scrollFrame - note
    # that we are never going to paint the scrollFrame
    # we are updating the alpha so that its value is the same as the
    # contained frame
    @alpha = @calculateAlphaScaled(alpha)
    @contents.setAlphaScaled(alpha)

  adjustScrollBars: ->
    hWidth = @width() - @scrollBarSize
    vHeight = @height() - @scrollBarSize
    @changed()

    # this check is to see whether the bar actually belongs to this
    # scrollframe. The reason why the bar could belong to another
    # scrollframe is the following: the bar could have been detached
    # from a scrollframe A. The scrollframe A (which is still fully
    # working albeit detached) is then duplicated into
    # a scrollframe B. What happens is that because the bar is not
    # a child of A (rather, it's only referenced as a property),
    # the duplication mechanism does not duplicate the bar and it does
    # not update the reference to it. This is correct because one cannot
    # just change all the references to other objects that are not children
    # , a good example being the targets, i.e. if you duplicate a colorPicker
    # which targets a Morph you want the duplication of the colorPicker to
    # still change color of that same Morph.
    # So: the scrollframe B could still reference the scrollbar
    # detached from A and that causes a problem because changes to B would
    # change the dimensions and hiding/unhiding of the scrollbar.
    # So here we avoid that by actually checking what the scrollbar is
    # attached to.
    if @hBar.target == @ 
      if @contents.width() >= @width() + 1
        @hBar.show()
        @hBar.setWidth hWidth  if @hBar.width() isnt hWidth
        # we check whether the bar has been detached. If it's still
        # attached then we possibly move it, together with the
        # scrollframe, otherwise we don't move it.
        if @hBar.parent == @
          @hBar.setPosition new Point(@left(), @bottom() - @hBar.height())
        @hBar.start = 0
        @hBar.stop = @contents.width() - @width()
        @hBar.size = @width() / @contents.width() * @hBar.stop
        @hBar.value = @left() - @contents.left()
        @hBar.updateRendering()
      else
        @hBar.hide()

    # see comment on equivalent if line above.
    if @vBar.target == @ 
      if @contents.height() >= @height() + 1
        @vBar.show()
        @vBar.setHeight vHeight  if @vBar.height() isnt vHeight
        # we check whether the bar has been detached. If it's still
        # attached then we possibly move it, together with the
        # scrollframe, otherwise we don't move it.
        if @vBar.parent == @
          @vBar.setPosition new Point(@right() - @vBar.width(), @top())
        @vBar.start = 0
        @vBar.stop = @contents.height() - @height()
        @vBar.size = @height() / @contents.height() * @vBar.stop
        @vBar.value = @top() - @contents.top()
        @vBar.updateRendering()
      else
        @vBar.hide()
  
  addContents: (aMorph) ->
    @contents.add aMorph
    @contents.adjustBounds()
    @adjustScrollBars()
  
  setContents: (aMorph, extraPadding) ->
    @extraPadding = extraPadding
    @contents.destroyAll()
    #
    @contents.children = []
    aMorph.setPosition @position().add(@padding + @extraPadding)
    @addContents aMorph
  
  setExtent: (aPoint) ->
    @contents.setPosition @position().copy()  if @isTextLineWrapping
    super aPoint
    @contents.adjustBounds()
    @adjustScrollBars()
  
  # ScrollFrameMorph scrolling by dragging:
  scrollX: (steps) ->
    cl = @contents.left()
    l = @left()
    cw = @contents.width()
    r = @right()
    newX = cl + steps
    newX = r - cw  if newX + cw < r
    newX = l  if newX > l
    @contents.setLeft newX  if newX isnt cl
  
  scrollY: (steps) ->
    ct = @contents.top()
    t = @top()
    ch = @contents.height()
    b = @bottom()
    newY = ct + steps
    if newY + ch < b
      newY = b - ch
    # prevents content to be scrolled to the frame's
    # bottom if the content is otherwise empty
    newY = t  if newY > t
    @contents.setTop newY  if newY isnt ct
  
  mouseDownLeft: (pos) ->
    return null  unless @isScrollingByDragging
    world = @root()
    oldPos = pos
    deltaX = 0
    deltaY = 0
    friction = 0.8
    @step = =>
      if world.hand.mouseButton and
        (!world.hand.children.length) and
        (@bounds.containsPoint(world.hand.position()))
          newPos = world.hand.bounds.origin
          if @hBar.isVisible
            deltaX = newPos.x - oldPos.x
            @scrollX deltaX  if deltaX isnt 0
          if @vBar.isVisible
            deltaY = newPos.y - oldPos.y
            @scrollY deltaY  if deltaY isnt 0
          oldPos = newPos
      else
        unless @hasVelocity
          @step = noOperation
        else
          if (Math.abs(deltaX) < 0.5) and (Math.abs(deltaY) < 0.5)
            @step = noOperation
          else
            if @hBar.isVisible
              deltaX = deltaX * friction
              @scrollX Math.round(deltaX)
            if @vBar.isVisible
              deltaY = deltaY * friction
              @scrollY Math.round(deltaY)
      console.log "adjusting..."
      @contents.adjustBounds()
      @adjustScrollBars()
  
  startAutoScrolling: ->
    inset = WorldMorph.preferencesAndSettings.scrollBarSize * 3
    world = @world()
    return null  unless world
    hand = world.hand
    @autoScrollTrigger = Date.now()  unless @autoScrollTrigger
    @step = =>
      pos = hand.bounds.origin
      inner = @bounds.insetBy(inset)
      if (@bounds.containsPoint(pos)) and
        (not (inner.containsPoint(pos))) and
        (hand.children.length)
          @autoScroll pos
      else
        @step = noOperation
        @autoScrollTrigger = null
  
  autoScroll: (pos) ->
    return null  if Date.now() - @autoScrollTrigger < 500
    inset = WorldMorph.preferencesAndSettings.scrollBarSize * 3
    area = @topLeft().extent(new Point(@width(), inset))
    @scrollY inset - (pos.y - @top())  if area.containsPoint(pos)
    area = @topLeft().extent(new Point(inset, @height()))
    @scrollX inset - (pos.x - @left())  if area.containsPoint(pos)
    area = (new Point(@right() - inset, @top())).extent(new Point(inset, @height()))
    @scrollX -(inset - (@right() - pos.x))  if area.containsPoint(pos)
    area = (new Point(@left(), @bottom() - inset)).extent(new Point(@width(), inset))
    @scrollY -(inset - (@bottom() - pos.y))  if area.containsPoint(pos)
    @contents.adjustBounds()
    @adjustScrollBars()  
  
  # ScrollFrameMorph scrolling when editing text
  # so to bring the caret fully into view.
  scrollCaretIntoView: (caretMorph) ->
    txt = caretMorph.target
    offset = txt.position().subtract(@contents.position())
    ft = @top() + @padding
    fb = @bottom() - @padding
    fl = @left() + @padding
    fr = @right() - @padding
    @contents.adjustBounds()
    if caretMorph.top() < ft
      @contents.setTop @contents.top() + ft - caretMorph.top()
      caretMorph.setTop ft
    else if caretMorph.bottom() > fb
      @contents.setBottom @contents.bottom() + fb - caretMorph.bottom()
      caretMorph.setBottom fb
    if caretMorph.left() < fl
      @contents.setLeft @contents.left() + fl - caretMorph.left()
      caretMorph.setLeft fl
    else if caretMorph.right() > fr
      @contents.setRight @contents.right() + fr - caretMorph.right()
      caretMorph.setRight fr
    @contents.adjustBounds()
    @adjustScrollBars()

  # ScrollFrameMorph events:
  mouseScroll: (y, x) ->
    @scrollY y * WorldMorph.preferencesAndSettings.mouseScrollAmount  if y
    @scrollX x * WorldMorph.preferencesAndSettings.mouseScrollAmount  if x
    @contents.adjustBounds()
    @adjustScrollBars()
  
  
  developersMenu: ->
    menu = super()
    if @isTextLineWrapping
      menu.addItem "auto line wrap off...", (->@toggleTextLineWrapping()), "turn automatic\nline wrapping\noff"
    else
      menu.addItem "auto line wrap on...", (->@toggleTextLineWrapping()), "enable automatic\nline wrapping"
    menu
  
  toggleTextLineWrapping: ->
    @isTextLineWrapping = not @isTextLineWrapping
  '''

# ListMorph ///////////////////////////////////////////////////////////

class ListMorph extends ScrollFrameMorph
  
  elements: null
  labelGetter: null
  format: null
  listContents: null
  selected: null # actual element currently selected
  active: null # menu item representing the selected element
  action: null
  target: null
  doubleClickAction: null

  constructor: (@target, @action, @elements = [], labelGetter, @format = [], @doubleClickAction = null) ->
    #
    #    passing a format is optional. If the format parameter is specified
    #    it has to be of the following pattern:
    #
    #        [
    #            [<color>, <single-argument predicate>],
    #            ['bold', <single-argument predicate>],
    #            ['italic', <single-argument predicate>],
    #            ...
    #        ]
    #
    #    multiple conditions can be passed in such a format list, the
    #    last predicate to evaluate true when given the list element sets
    #    the given format category (color, bold, italic).
    #    If no condition is met, the default format (color black, non-bold,
    #    non-italic) will be assigned.
    #    
    #    An example of how to use fomats can be found in the InspectorMorph's
    #    "markOwnProperties" mechanism.
    #
    #debugger
    super()
    @contents.acceptsDrops = false
    @color = new Color(255, 255, 255)
    @labelGetter = labelGetter or (element) ->
        return element  if isString(element)
        return element.toSource()  if element.toSource
        element.toString()
    @buildListContents()
    # it's important to leave the step as the default noOperation
    # instead of null because the scrollbars (inherited from scrollframe)
    # need the step function to react to mouse drag.
  
  buildListContents: ->
    if @listContents
      @listContents = @listContents.destroy()
    @listContents = new MenuMorph(@, null, null)
    @elements = ["(empty)"]  if !@elements.length
    @elements.forEach (element) =>
      color = null
      bold = false
      italic = false
      @format.forEach (pair) ->
        if pair[1].call(null, element)
          if pair[0] == 'bold'
            bold = true
          else if pair[0] == 'italic'
            italic = true
          else # assume it's a color
            color = pair[0]
      #
      #labelString,
      #action,
      #hint,
      #color,
      #bold = false,
      #italic = false,
      #doubleClickAction # optional, when used as list contents
      @listContents.addItem @labelGetter(element), @select, null, color, bold, italic, @doubleClickAction
    #
    @listContents.setPosition @contents.position()
    @listContents.isListContents = true
    @listContents.updateRendering()
    @addContents @listContents
  
  select: (item, trigger) ->
    @selected = item
    @active = trigger
    if @action
      @action.call @target, item.labelString
  
  setExtent: (aPoint) ->
    lb = @listContents.bounds
    nb = @bounds.origin.copy().corner(@bounds.origin.add(aPoint))
    if nb.right() > lb.right() and nb.width() <= lb.width()
      @listContents.setRight nb.right()
    if nb.bottom() > lb.bottom() and nb.height() <= lb.height()
      @listContents.setBottom nb.bottom()
    super aPoint

  @coffeeScriptSourceOfThisClass: '''
# ListMorph ///////////////////////////////////////////////////////////

class ListMorph extends ScrollFrameMorph
  
  elements: null
  labelGetter: null
  format: null
  listContents: null
  selected: null # actual element currently selected
  active: null # menu item representing the selected element
  action: null
  target: null
  doubleClickAction: null

  constructor: (@target, @action, @elements = [], labelGetter, @format = [], @doubleClickAction = null) ->
    #
    #    passing a format is optional. If the format parameter is specified
    #    it has to be of the following pattern:
    #
    #        [
    #            [<color>, <single-argument predicate>],
    #            ['bold', <single-argument predicate>],
    #            ['italic', <single-argument predicate>],
    #            ...
    #        ]
    #
    #    multiple conditions can be passed in such a format list, the
    #    last predicate to evaluate true when given the list element sets
    #    the given format category (color, bold, italic).
    #    If no condition is met, the default format (color black, non-bold,
    #    non-italic) will be assigned.
    #    
    #    An example of how to use fomats can be found in the InspectorMorph's
    #    "markOwnProperties" mechanism.
    #
    #debugger
    super()
    @contents.acceptsDrops = false
    @color = new Color(255, 255, 255)
    @labelGetter = labelGetter or (element) ->
        return element  if isString(element)
        return element.toSource()  if element.toSource
        element.toString()
    @buildListContents()
    # it's important to leave the step as the default noOperation
    # instead of null because the scrollbars (inherited from scrollframe)
    # need the step function to react to mouse drag.
  
  buildListContents: ->
    if @listContents
      @listContents = @listContents.destroy()
    @listContents = new MenuMorph(@, null, null)
    @elements = ["(empty)"]  if !@elements.length
    @elements.forEach (element) =>
      color = null
      bold = false
      italic = false
      @format.forEach (pair) ->
        if pair[1].call(null, element)
          if pair[0] == 'bold'
            bold = true
          else if pair[0] == 'italic'
            italic = true
          else # assume it's a color
            color = pair[0]
      #
      #labelString,
      #action,
      #hint,
      #color,
      #bold = false,
      #italic = false,
      #doubleClickAction # optional, when used as list contents
      @listContents.addItem @labelGetter(element), @select, null, color, bold, italic, @doubleClickAction
    #
    @listContents.setPosition @contents.position()
    @listContents.isListContents = true
    @listContents.updateRendering()
    @addContents @listContents
  
  select: (item, trigger) ->
    @selected = item
    @active = trigger
    if @action
      @action.call @target, item.labelString
  
  setExtent: (aPoint) ->
    lb = @listContents.bounds
    nb = @bounds.origin.copy().corner(@bounds.origin.add(aPoint))
    if nb.right() > lb.right() and nb.width() <= lb.width()
      @listContents.setRight nb.right()
    if nb.bottom() > lb.bottom() and nb.height() <= lb.height()
      @listContents.setBottom nb.bottom()
    super aPoint
  '''

# TriggerMorph ////////////////////////////////////////////////////////

# I provide basic button functionality.
# All menu items and buttons are TriggerMorphs.
# The handling of the triggering is not
# trivial, as the concepts of
# dataSourceMorphForTarget, target and action
# are used - see comments.

class TriggerMorph extends Morph

  target: null
  action: null
  dataSourceMorphForTarget: null
  label: null
  labelString: null
  labelColor: null
  labelBold: null
  labelItalic: null
  doubleClickAction: null
  hint: null
  fontSize: null
  fontStyle: null
  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  highlightColor: new Color(192, 192, 192)
  highlightImage: null
  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  pressColor: new Color(128, 128, 128)
  normalImage: null
  pressImage: null
  centered: false

  constructor: (
      @target = null,
      @action = null,
      @labelString = null,
      fontSize,
      fontStyle,
      @centered = false,
      @dataSourceMorphForTarget = null,
      @hint = null,
      labelColor,
      @labelBold = false,
      @labelItalic = false
      @doubleClickAction = null) ->

    # additional properties:
    @fontSize = fontSize or WorldMorph.preferencesAndSettings.menuFontSize
    @fontStyle = fontStyle or "sans-serif"
    @labelColor = labelColor or new Color(0, 0, 0)
    #
    super()
    #
    #@color = new Color(255, 152, 152)
    @color = new Color(255, 255, 255)
    if @labelString?
      @layoutSubmorphs()
  
  layoutSubmorphs: ->
    if not @label?
      @createLabel()
    if @centered
      @label.setPosition @center().subtract(@label.extent().floorDivideBy(2))

  setLabel: (@labelString) ->
    # just recreated the label
    # from scratch
    if @label?
      @label = @label.destroy()
    @layoutSubmorphs()

  alignCenter: ->
    if !@centered
      @centered = true
      @layoutSubmorphs()

  alignLeft: ->
    if @centered
      @centered = false
      @layoutSubmorphs()
  
  updateRendering: ->
    ext = @extent()
    @normalImage = newCanvas(ext.scaleBy pixelRatio)
    context = @normalImage.getContext("2d")
    context.scale pixelRatio, pixelRatio
    context.fillStyle = @color.toString()
    context.fillRect 0, 0, ext.x, ext.y
    @highlightImage = newCanvas(ext.scaleBy pixelRatio)
    context = @highlightImage.getContext("2d")
    context.scale pixelRatio, pixelRatio
    context.fillStyle = @highlightColor.toString()
    context.fillRect 0, 0, ext.x, ext.y
    @pressImage = newCanvas(ext.scaleBy pixelRatio)
    context = @pressImage.getContext("2d")
    context.scale pixelRatio, pixelRatio
    context.fillStyle = @pressColor.toString()
    context.fillRect 0, 0, ext.x, ext.y
    @image = @normalImage
  
  createLabel: ->
    # bold
    # italic
    # numeric
    # shadow offset
    # shadow color
    @label = new StringMorph(
      @labelString or "",
      @fontSize,
      @fontStyle,
      false,
      false,
      false,
      null,
      null,
      @labelColor,
      @labelBold,
      @labelItalic
    )
    @add @label
    
  
  # TriggerMorph action:
  trigger: ->
    @action.call @target, @dataSourceMorphForTarget

  triggerDoubleClick: ->
    # same as trigger() but use doubleClickAction instead of action property
    # note that specifying a doubleClickAction is optional
    return  unless @doubleClickAction
    if typeof @target is "function"
      if typeof @doubleClickAction is "function"
        @target.call @dataSourceMorphForTarget, @doubleClickAction.call(), this
      else
        @target.call @dataSourceMorphForTarget, @doubleClickAction, this
    else
      if typeof @doubleClickAction is "function"
        @doubleClickAction.call @target
      else # assume it's a String
        @target[@doubleClickAction]()  
  
  # TriggerMorph events:
  mouseEnter: ->
    @image = @highlightImage
    @changed()
    @startCountdownForBubbleHelp @hint  if @hint
  
  mouseLeave: ->
    @image = @normalImage
    @changed()
    @world().hand.destroyTemporaries()  if @hint
  
  mouseDownLeft: ->
    @image = @pressImage
    @changed()
  
  mouseClickLeft: ->
    @image = @highlightImage
    @changed()
    @trigger()

  mouseDoubleClick: ->
    @triggerDoubleClick()

  # Disable dragging compound Morphs by Triggers
  # User can still move the trigger itself though
  # (it it's unlocked)
  rootForGrab: ->
    if @isDraggable
      return super()
    null
  
  # TriggerMorph bubble help:
  startCountdownForBubbleHelp: (contents) ->
    SpeechBubbleMorph.createInAWhileIfHandStillContainedInMorph @, contents

  @coffeeScriptSourceOfThisClass: '''
# TriggerMorph ////////////////////////////////////////////////////////

# I provide basic button functionality.
# All menu items and buttons are TriggerMorphs.
# The handling of the triggering is not
# trivial, as the concepts of
# dataSourceMorphForTarget, target and action
# are used - see comments.

class TriggerMorph extends Morph

  target: null
  action: null
  dataSourceMorphForTarget: null
  label: null
  labelString: null
  labelColor: null
  labelBold: null
  labelItalic: null
  doubleClickAction: null
  hint: null
  fontSize: null
  fontStyle: null
  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  highlightColor: new Color(192, 192, 192)
  highlightImage: null
  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  pressColor: new Color(128, 128, 128)
  normalImage: null
  pressImage: null
  centered: false

  constructor: (
      @target = null,
      @action = null,
      @labelString = null,
      fontSize,
      fontStyle,
      @centered = false,
      @dataSourceMorphForTarget = null,
      @hint = null,
      labelColor,
      @labelBold = false,
      @labelItalic = false
      @doubleClickAction = null) ->

    # additional properties:
    @fontSize = fontSize or WorldMorph.preferencesAndSettings.menuFontSize
    @fontStyle = fontStyle or "sans-serif"
    @labelColor = labelColor or new Color(0, 0, 0)
    #
    super()
    #
    #@color = new Color(255, 152, 152)
    @color = new Color(255, 255, 255)
    if @labelString?
      @layoutSubmorphs()
  
  layoutSubmorphs: ->
    if not @label?
      @createLabel()
    if @centered
      @label.setPosition @center().subtract(@label.extent().floorDivideBy(2))

  setLabel: (@labelString) ->
    # just recreated the label
    # from scratch
    if @label?
      @label = @label.destroy()
    @layoutSubmorphs()

  alignCenter: ->
    if !@centered
      @centered = true
      @layoutSubmorphs()

  alignLeft: ->
    if @centered
      @centered = false
      @layoutSubmorphs()
  
  updateRendering: ->
    ext = @extent()
    @normalImage = newCanvas(ext.scaleBy pixelRatio)
    context = @normalImage.getContext("2d")
    context.scale pixelRatio, pixelRatio
    context.fillStyle = @color.toString()
    context.fillRect 0, 0, ext.x, ext.y
    @highlightImage = newCanvas(ext.scaleBy pixelRatio)
    context = @highlightImage.getContext("2d")
    context.scale pixelRatio, pixelRatio
    context.fillStyle = @highlightColor.toString()
    context.fillRect 0, 0, ext.x, ext.y
    @pressImage = newCanvas(ext.scaleBy pixelRatio)
    context = @pressImage.getContext("2d")
    context.scale pixelRatio, pixelRatio
    context.fillStyle = @pressColor.toString()
    context.fillRect 0, 0, ext.x, ext.y
    @image = @normalImage
  
  createLabel: ->
    # bold
    # italic
    # numeric
    # shadow offset
    # shadow color
    @label = new StringMorph(
      @labelString or "",
      @fontSize,
      @fontStyle,
      false,
      false,
      false,
      null,
      null,
      @labelColor,
      @labelBold,
      @labelItalic
    )
    @add @label
    
  
  # TriggerMorph action:
  trigger: ->
    @action.call @target, @dataSourceMorphForTarget

  triggerDoubleClick: ->
    # same as trigger() but use doubleClickAction instead of action property
    # note that specifying a doubleClickAction is optional
    return  unless @doubleClickAction
    if typeof @target is "function"
      if typeof @doubleClickAction is "function"
        @target.call @dataSourceMorphForTarget, @doubleClickAction.call(), this
      else
        @target.call @dataSourceMorphForTarget, @doubleClickAction, this
    else
      if typeof @doubleClickAction is "function"
        @doubleClickAction.call @target
      else # assume it's a String
        @target[@doubleClickAction]()  
  
  # TriggerMorph events:
  mouseEnter: ->
    @image = @highlightImage
    @changed()
    @startCountdownForBubbleHelp @hint  if @hint
  
  mouseLeave: ->
    @image = @normalImage
    @changed()
    @world().hand.destroyTemporaries()  if @hint
  
  mouseDownLeft: ->
    @image = @pressImage
    @changed()
  
  mouseClickLeft: ->
    @image = @highlightImage
    @changed()
    @trigger()

  mouseDoubleClick: ->
    @triggerDoubleClick()

  # Disable dragging compound Morphs by Triggers
  # User can still move the trigger itself though
  # (it it's unlocked)
  rootForGrab: ->
    if @isDraggable
      return super()
    null
  
  # TriggerMorph bubble help:
  startCountdownForBubbleHelp: (contents) ->
    SpeechBubbleMorph.createInAWhileIfHandStillContainedInMorph @, contents
  '''

# MenuItemMorph ///////////////////////////////////////////////////////

# I automatically determine my bounds

class MenuItemMorph extends TriggerMorph

  # labelString can also be a Morph or a Canvas or a tuple: [icon, string]
  constructor: (target, action, labelString, fontSize, fontStyle, centered, environment, hint, color, bold, italic, doubleClickAction) ->
    #console.log "menuitem constructing"
    super target, action, labelString, fontSize, fontStyle, centered, environment, hint, color, bold, italic, doubleClickAction 
  
  createLabel: ->
    # console.log "menuitem createLabel"
    if @label?
      @label = @label.destroy()

    if isString(@labelString)
      @label = @createLabelString(@labelString)
    else if @labelString instanceof Array      
      # assume its pattern is: [icon, string] 
      @label = new Morph()
      @label.alpha = 0 # transparent

      icon = @createIcon(@labelString[0])
      @label.add icon
      lbl = @createLabelString(@labelString[1])
      @label.add lbl

      lbl.setCenter icon.center()
      lbl.setLeft icon.right() + 4
      @label.bounds = (icon.bounds.merge(lbl.bounds))
    else # assume it's either a Morph or a Canvas
      @label = @createIcon(@labelString)

    @add @label
  
    w = @width()
    @silentSetExtent @label.extent().add(new Point(8, 0))
    @silentSetWidth w
    np = @position().add(new Point(4, 0))
    @label.bounds = np.extent(@label.extent())
  
  createIcon: (source) ->
    # source can be either a Morph or an HTMLCanvasElement
    icon = new Morph()
    icon.image = (if source instanceof Morph then source.fullImage() else source)

    # adjust shadow dimensions
    if source instanceof Morph and source.getShadow()
      src = icon.image
      icon.image = newCanvas(
        source.fullBounds().extent().subtract(
          @shadowBlur * ((if WorldMorph.preferencesAndSettings.useBlurredShadows then 1 else 2))).scaleBy pixelRatio)
      context = icon.image.getContext("2d")
      #context.scale pixelRatio, pixelRatio
      context.drawImage src, 0, 0

    icon.silentSetWidth icon.image.width
    icon.silentSetHeight icon.image.height
    icon

  createLabelString: (string) ->
    # console.log "menuitem createLabelString"
    lbl = new TextMorph(string, @fontSize, @fontStyle)
    lbl.setColor @labelColor
    lbl  

  # MenuItemMorph events:
  mouseEnter: ->
    unless @isListItem()
      @image = @highlightImage
      @changed()
    if @hint
      @startCountdownForBubbleHelp @hint
  
  mouseLeave: ->
    unless @isListItem()
      @image = @normalImage
      @changed()
    world.hand.destroyTemporaries()  if @hint
  
  mouseDownLeft: (pos) ->
    if @isListItem()
      @parent.unselectAllItems()
      @escalateEvent "mouseDownLeft", pos
    @image = @pressImage
    @changed()
  
  mouseMove: ->
    @escalateEvent "mouseMove"  if @isListItem()
  
  mouseClickLeft: ->
    @trigger()
    # this might now destroy the
    # menu this morph is in
    # The menu item might be detached
    # from the menu so check existence of
    # method
    if @parent.itemSelected
      @parent.itemSelected()
  
  isListItem: ->
    return @parent.isListContents  if @parent
    false
  
  isSelectedListItem: ->
    return @image is @pressImage  if @isListItem()
    false

  @coffeeScriptSourceOfThisClass: '''
# MenuItemMorph ///////////////////////////////////////////////////////

# I automatically determine my bounds

class MenuItemMorph extends TriggerMorph

  # labelString can also be a Morph or a Canvas or a tuple: [icon, string]
  constructor: (target, action, labelString, fontSize, fontStyle, centered, environment, hint, color, bold, italic, doubleClickAction) ->
    #console.log "menuitem constructing"
    super target, action, labelString, fontSize, fontStyle, centered, environment, hint, color, bold, italic, doubleClickAction 
  
  createLabel: ->
    # console.log "menuitem createLabel"
    if @label?
      @label = @label.destroy()

    if isString(@labelString)
      @label = @createLabelString(@labelString)
    else if @labelString instanceof Array      
      # assume its pattern is: [icon, string] 
      @label = new Morph()
      @label.alpha = 0 # transparent

      icon = @createIcon(@labelString[0])
      @label.add icon
      lbl = @createLabelString(@labelString[1])
      @label.add lbl

      lbl.setCenter icon.center()
      lbl.setLeft icon.right() + 4
      @label.bounds = (icon.bounds.merge(lbl.bounds))
    else # assume it's either a Morph or a Canvas
      @label = @createIcon(@labelString)

    @add @label
  
    w = @width()
    @silentSetExtent @label.extent().add(new Point(8, 0))
    @silentSetWidth w
    np = @position().add(new Point(4, 0))
    @label.bounds = np.extent(@label.extent())
  
  createIcon: (source) ->
    # source can be either a Morph or an HTMLCanvasElement
    icon = new Morph()
    icon.image = (if source instanceof Morph then source.fullImage() else source)

    # adjust shadow dimensions
    if source instanceof Morph and source.getShadow()
      src = icon.image
      icon.image = newCanvas(
        source.fullBounds().extent().subtract(
          @shadowBlur * ((if WorldMorph.preferencesAndSettings.useBlurredShadows then 1 else 2))).scaleBy pixelRatio)
      context = icon.image.getContext("2d")
      #context.scale pixelRatio, pixelRatio
      context.drawImage src, 0, 0

    icon.silentSetWidth icon.image.width
    icon.silentSetHeight icon.image.height
    icon

  createLabelString: (string) ->
    # console.log "menuitem createLabelString"
    lbl = new TextMorph(string, @fontSize, @fontStyle)
    lbl.setColor @labelColor
    lbl  

  # MenuItemMorph events:
  mouseEnter: ->
    unless @isListItem()
      @image = @highlightImage
      @changed()
    if @hint
      @startCountdownForBubbleHelp @hint
  
  mouseLeave: ->
    unless @isListItem()
      @image = @normalImage
      @changed()
    world.hand.destroyTemporaries()  if @hint
  
  mouseDownLeft: (pos) ->
    if @isListItem()
      @parent.unselectAllItems()
      @escalateEvent "mouseDownLeft", pos
    @image = @pressImage
    @changed()
  
  mouseMove: ->
    @escalateEvent "mouseMove"  if @isListItem()
  
  mouseClickLeft: ->
    @trigger()
    # this might now destroy the
    # menu this morph is in
    # The menu item might be detached
    # from the menu so check existence of
    # method
    if @parent.itemSelected
      @parent.itemSelected()
  
  isListItem: ->
    return @parent.isListContents  if @parent
    false
  
  isSelectedListItem: ->
    return @image is @pressImage  if @isListItem()
    false
  '''

# MenuMorph ///////////////////////////////////////////////////////////

class MenuMorph extends BoxMorph

  target: null
  title: null
  environment: null
  fontSize: null
  items: null
  label: null
  isListContents: false

  constructor: (@target, @title = null, @environment = null, @fontSize = null) ->
    # console.log "menu constructor"
    # Note that Morph does a updateRendering upon creation (TODO Why?), so we need
    # to initialise the items before calling super. We can't initialise it
    # outside the constructor because the array would be shared across instantiated
    # objects.
    @items = []
    # console.log "menu super"
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.alignmentOfMorphIDsMechanism
      world.alignIDsOfNextMorphsInSystemTests()
    super()

    @border = null # the Box Morph constructor puts this to 2
    # important not to traverse all the children for stepping through, because
    # there could be a lot of entries for example in the inspector the number
    # of properties of an object - there could be a 100 of those and we don't
    # want to traverse them all. Setting step to null (as opposed to nop)
    # achieves that.
  
  addItem: (
      labelString,
      action,
      hint,
      color,
      bold = false,
      italic = false,
      doubleClickAction # optional, when used as list contents
      ) ->
    # labelString is normally a single-line string. But it can also be one
    # of the following:
    #     * a multi-line string (containing line breaks)
    #     * an icon (either a Morph or a Canvas)
    #     * a tuple of format: [icon, string]
    @items.push [
      localize(labelString or "close"),
      action or nop,
      hint,
      color,
      bold,
      italic,
      doubleClickAction
    ]

  prependItem: (
      labelString,
      action,
      hint,
      color,
      bold = false,
      italic = false,
      doubleClickAction # optional, when used as list contents
      ) ->
    # labelString is normally a single-line string. But it can also be one
    # of the following:
    #     * a multi-line string (containing line breaks)
    #     * an icon (either a Morph or a Canvas)
    #     * a tuple of format: [icon, string]
    @items.unshift [
      localize(labelString or "close"),
      action or nop,
      hint,
      color,
      bold,
      italic,
      doubleClickAction
    ]
  
  addLine: (width) ->
    @items.push [0, width or 1]

  prependLine: (width) ->
    @items.unshift [0, width or 1]
  
  createLabel: ->
    # console.log "menu create label"
    if @label?
      @label = @label.destroy()
    text = new TextMorph(localize(@title),
      @fontSize or WorldMorph.preferencesAndSettings.menuFontSize,
      WorldMorph.preferencesAndSettings.menuFontName, true, false, "center")
    text.alignment = "center"
    text.color = new Color(255, 255, 255)
    text.backgroundColor = @borderColor

    @label = new BoxMorph(3, 0)
    @label.add text
    if WorldMorph.preferencesAndSettings.isFlat
      @label.edge = 0
    @label.color = @borderColor
    @label.borderColor = @borderColor
    @label.setExtent text.extent().add(4) # here!
    @label.text = text
  
  updateRendering: ->
    # console.log "menu update rendering"
    isLine = false
    @destroyAll()
    #
    @children = []
    unless @isListContents
      @edge = if WorldMorph.preferencesAndSettings.isFlat then 0 else 5
      @border = if WorldMorph.preferencesAndSettings.isFlat then 1 else 2
    @color = new Color(255, 255, 255)
    @borderColor = new Color(60, 60, 60)
    @silentSetExtent new Point(0, 0)
    y = @top() + 2
    x = @left() + 4


    unless @isListContents
      if @title
        @createLabel()
        @label.setPosition @bounds.origin.add(4)
        @add @label
        y = @label.bottom()
      else
        y = @top() + 4
    y += 1

    # note that menus can contain:
    # strings, colorpickers,
    # sliders, menuItems (which are buttons)
    # and lines.
    # console.log "menu @items.length " + @items.length
    @items.forEach (tuple) =>
      isLine = false
      # string, color picker and slider
      if tuple instanceof StringFieldMorph or
        tuple instanceof ColorPickerMorph or
        tuple instanceof SliderMorph
          item = tuple
      # line. A thin Morph is used
      # to draw the line.
      else if tuple[0] is 0
        isLine = true
        item = new Morph()
        item.color = @borderColor
        item.setHeight tuple[1]
      # menuItem
      else
        # console.log "menu creating MenuItemMorph "
        item = new MenuItemMorph(
          @target,
          tuple[1], # action
          tuple[0], # target
          @fontSize or WorldMorph.preferencesAndSettings.menuFontSize,
          WorldMorph.preferencesAndSettings.menuFontName,
          false,
          @environment,
          tuple[2], # bubble help hint
          tuple[3], # color
          tuple[4], # bold
          tuple[5], # italic
          tuple[6]  # doubleclick action
          )
        if !@environment?
          item.dataSourceMorphForTarget = item
      y += 1  if isLine
      item.setPosition new Point(x, y)
      @add item
      #console.log "item added: " + item.bounds
      y = y + item.height()
      y += 1  if isLine
  
    @adjustWidthsOfMenuEntries()
    fb = @boundsIncludingChildren()
    #console.log "fb: " + fb
    @silentSetExtent fb.extent().add(4)
  
    super()
  
  maxWidth: ->
    w = 0
    if @parent instanceof FrameMorph
      if @parent.scrollFrame instanceof ScrollFrameMorph
        w = @parent.scrollFrame.width()    
    @children.forEach (item) ->
      if (item instanceof MenuItemMorph)
        w = Math.max(w, item.children[0].width() + 8)
      else if (item instanceof StringFieldMorph) or
        (item instanceof ColorPickerMorph) or
        (item instanceof SliderMorph)
          w = Math.max(w, item.width())  
    #
    w = Math.max(w, @label.width())  if @label
    w
  
  # makes all the elements of this menu the
  # right width.
  adjustWidthsOfMenuEntries: ->
    w = @maxWidth()
    @children.forEach (item) =>
      item.setWidth w
      if item instanceof MenuItemMorph
        isSelected = (item.image == item.pressImage)
        item.layoutSubmorphs()
        if isSelected then item.image = item.pressImage          
      else
        if item is @label
          item.text.setPosition item.center().subtract(item.text.extent().floorDivideBy(2))
  
  
  unselectAllItems: ->
    @children.forEach (item) ->
      item.image = item.normalImage  if item instanceof MenuItemMorph
    #
    @changed()

  itemSelected: ->
    unless @isListContents
      world.unfocusMenu @
      @destroy()
  
  popup: (world, pos) ->
    # console.log "menu popup"
    # keep only one active menu at a time, destroy the
    # previous one.
    if world.activeMenu
      world.activeMenu = world.activeMenu.destroy()
    @setPosition pos
    world.add @
    # the @keepWithin method
    # needs to know the extent of the morph
    # so it must be called after the world.add
    # method. If you call before, there is
    # nopainting happening and the morph doesn't
    # know its extent.
    @keepWithin world
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.alignmentOfMorphIDsMechanism
      world.alignIDsOfNextMorphsInSystemTests()
    # shadow must be added after the morph
    # has been placed somewhere because
    # otherwise there is no visible image
    # to base the shadow on
    @addShadow new Point(2, 2), 80
    world.activeMenu = @
    @fullChanged()
  
  popUpAtHand: ->
    @popup world, world.hand.position()
  
  popUpCenteredAtHand: (world) ->
    wrrld = world or @world()
    @popup wrrld, wrrld.hand.position().subtract(@extent().floorDivideBy(2))
  
  popUpCenteredInWorld: (world) ->
    wrrld = world or @world()
    @popup wrrld, wrrld.center().subtract(@extent().floorDivideBy(2))

  @coffeeScriptSourceOfThisClass: '''
# MenuMorph ///////////////////////////////////////////////////////////

class MenuMorph extends BoxMorph

  target: null
  title: null
  environment: null
  fontSize: null
  items: null
  label: null
  isListContents: false

  constructor: (@target, @title = null, @environment = null, @fontSize = null) ->
    # console.log "menu constructor"
    # Note that Morph does a updateRendering upon creation (TODO Why?), so we need
    # to initialise the items before calling super. We can't initialise it
    # outside the constructor because the array would be shared across instantiated
    # objects.
    @items = []
    # console.log "menu super"
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.alignmentOfMorphIDsMechanism
      world.alignIDsOfNextMorphsInSystemTests()
    super()

    @border = null # the Box Morph constructor puts this to 2
    # important not to traverse all the children for stepping through, because
    # there could be a lot of entries for example in the inspector the number
    # of properties of an object - there could be a 100 of those and we don't
    # want to traverse them all. Setting step to null (as opposed to nop)
    # achieves that.
  
  addItem: (
      labelString,
      action,
      hint,
      color,
      bold = false,
      italic = false,
      doubleClickAction # optional, when used as list contents
      ) ->
    # labelString is normally a single-line string. But it can also be one
    # of the following:
    #     * a multi-line string (containing line breaks)
    #     * an icon (either a Morph or a Canvas)
    #     * a tuple of format: [icon, string]
    @items.push [
      localize(labelString or "close"),
      action or nop,
      hint,
      color,
      bold,
      italic,
      doubleClickAction
    ]

  prependItem: (
      labelString,
      action,
      hint,
      color,
      bold = false,
      italic = false,
      doubleClickAction # optional, when used as list contents
      ) ->
    # labelString is normally a single-line string. But it can also be one
    # of the following:
    #     * a multi-line string (containing line breaks)
    #     * an icon (either a Morph or a Canvas)
    #     * a tuple of format: [icon, string]
    @items.unshift [
      localize(labelString or "close"),
      action or nop,
      hint,
      color,
      bold,
      italic,
      doubleClickAction
    ]
  
  addLine: (width) ->
    @items.push [0, width or 1]

  prependLine: (width) ->
    @items.unshift [0, width or 1]
  
  createLabel: ->
    # console.log "menu create label"
    if @label?
      @label = @label.destroy()
    text = new TextMorph(localize(@title),
      @fontSize or WorldMorph.preferencesAndSettings.menuFontSize,
      WorldMorph.preferencesAndSettings.menuFontName, true, false, "center")
    text.alignment = "center"
    text.color = new Color(255, 255, 255)
    text.backgroundColor = @borderColor

    @label = new BoxMorph(3, 0)
    @label.add text
    if WorldMorph.preferencesAndSettings.isFlat
      @label.edge = 0
    @label.color = @borderColor
    @label.borderColor = @borderColor
    @label.setExtent text.extent().add(4) # here!
    @label.text = text
  
  updateRendering: ->
    # console.log "menu update rendering"
    isLine = false
    @destroyAll()
    #
    @children = []
    unless @isListContents
      @edge = if WorldMorph.preferencesAndSettings.isFlat then 0 else 5
      @border = if WorldMorph.preferencesAndSettings.isFlat then 1 else 2
    @color = new Color(255, 255, 255)
    @borderColor = new Color(60, 60, 60)
    @silentSetExtent new Point(0, 0)
    y = @top() + 2
    x = @left() + 4


    unless @isListContents
      if @title
        @createLabel()
        @label.setPosition @bounds.origin.add(4)
        @add @label
        y = @label.bottom()
      else
        y = @top() + 4
    y += 1

    # note that menus can contain:
    # strings, colorpickers,
    # sliders, menuItems (which are buttons)
    # and lines.
    # console.log "menu @items.length " + @items.length
    @items.forEach (tuple) =>
      isLine = false
      # string, color picker and slider
      if tuple instanceof StringFieldMorph or
        tuple instanceof ColorPickerMorph or
        tuple instanceof SliderMorph
          item = tuple
      # line. A thin Morph is used
      # to draw the line.
      else if tuple[0] is 0
        isLine = true
        item = new Morph()
        item.color = @borderColor
        item.setHeight tuple[1]
      # menuItem
      else
        # console.log "menu creating MenuItemMorph "
        item = new MenuItemMorph(
          @target,
          tuple[1], # action
          tuple[0], # target
          @fontSize or WorldMorph.preferencesAndSettings.menuFontSize,
          WorldMorph.preferencesAndSettings.menuFontName,
          false,
          @environment,
          tuple[2], # bubble help hint
          tuple[3], # color
          tuple[4], # bold
          tuple[5], # italic
          tuple[6]  # doubleclick action
          )
        if !@environment?
          item.dataSourceMorphForTarget = item
      y += 1  if isLine
      item.setPosition new Point(x, y)
      @add item
      #console.log "item added: " + item.bounds
      y = y + item.height()
      y += 1  if isLine
  
    @adjustWidthsOfMenuEntries()
    fb = @boundsIncludingChildren()
    #console.log "fb: " + fb
    @silentSetExtent fb.extent().add(4)
  
    super()
  
  maxWidth: ->
    w = 0
    if @parent instanceof FrameMorph
      if @parent.scrollFrame instanceof ScrollFrameMorph
        w = @parent.scrollFrame.width()    
    @children.forEach (item) ->
      if (item instanceof MenuItemMorph)
        w = Math.max(w, item.children[0].width() + 8)
      else if (item instanceof StringFieldMorph) or
        (item instanceof ColorPickerMorph) or
        (item instanceof SliderMorph)
          w = Math.max(w, item.width())  
    #
    w = Math.max(w, @label.width())  if @label
    w
  
  # makes all the elements of this menu the
  # right width.
  adjustWidthsOfMenuEntries: ->
    w = @maxWidth()
    @children.forEach (item) =>
      item.setWidth w
      if item instanceof MenuItemMorph
        isSelected = (item.image == item.pressImage)
        item.layoutSubmorphs()
        if isSelected then item.image = item.pressImage          
      else
        if item is @label
          item.text.setPosition item.center().subtract(item.text.extent().floorDivideBy(2))
  
  
  unselectAllItems: ->
    @children.forEach (item) ->
      item.image = item.normalImage  if item instanceof MenuItemMorph
    #
    @changed()

  itemSelected: ->
    unless @isListContents
      world.unfocusMenu @
      @destroy()
  
  popup: (world, pos) ->
    # console.log "menu popup"
    # keep only one active menu at a time, destroy the
    # previous one.
    if world.activeMenu
      world.activeMenu = world.activeMenu.destroy()
    @setPosition pos
    world.add @
    # the @keepWithin method
    # needs to know the extent of the morph
    # so it must be called after the world.add
    # method. If you call before, there is
    # nopainting happening and the morph doesn't
    # know its extent.
    @keepWithin world
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.alignmentOfMorphIDsMechanism
      world.alignIDsOfNextMorphsInSystemTests()
    # shadow must be added after the morph
    # has been placed somewhere because
    # otherwise there is no visible image
    # to base the shadow on
    @addShadow new Point(2, 2), 80
    world.activeMenu = @
    @fullChanged()
  
  popUpAtHand: ->
    @popup world, world.hand.position()
  
  popUpCenteredAtHand: (world) ->
    wrrld = world or @world()
    @popup wrrld, wrrld.hand.position().subtract(@extent().floorDivideBy(2))
  
  popUpCenteredInWorld: (world) ->
    wrrld = world or @world()
    @popup wrrld, wrrld.center().subtract(@extent().floorDivideBy(2))
  '''

# MorphsListMorph //////////////////////////////////////////////////////

class MorphsListMorph extends BoxMorph

  # panes:
  morphsList: null
  buttonClose: null
  resizer: null

  constructor: (target) ->
    super()

    @silentSetExtent new Point(
      WorldMorph.preferencesAndSettings.handleSize * 10,
      WorldMorph.preferencesAndSettings.handleSize * 20 * 2 / 3)
    @isDraggable = true
    @border = 1
    @edge = 5
    @color = new Color(60, 60, 60)
    @borderColor = new Color(95, 95, 95)
    @buildAndConnectChildren()
  
  setTarget: (target) ->
    @target = target
    @currentProperty = null
    @buildAndConnectChildren()
  
  buildAndConnectChildren: ->
    attribs = []

    # remove existing panes
    @destroyAll()

    @children = []

    # label
    @label = new TextMorph("Morphs List")
    @label.fontSize = WorldMorph.preferencesAndSettings.menuFontSize
    @label.isBold = true
    @label.color = new Color(255, 255, 255)
    @add @label

    # Check which objects end with the word Morph
    theWordMorph = "Morph"
    ListOfMorphs = (Object.keys(window)).filter (i) ->
      i.indexOf(theWordMorph, i.length - theWordMorph.length) isnt -1
    @morphsList = new ListMorph(ListOfMorphs, null)

    # so far nothing happens when items are selected
    #@morphsList.action = (selected) ->
    #  val = myself.target[selected]
    #  myself.currentProperty = val
    #  if val is null
    #    txt = "NULL"
    #  else if isString(val)
    #    txt = val
    #  else
    #    txt = val.toString()
    #  cnts = new TextMorph(txt)
    #  cnts.isEditable = true
    #  cnts.enableSelecting()
    #  cnts.setReceiver myself.target
    #  myself.detail.setContents cnts

    @morphsList.hBar.alpha = 0.6
    @morphsList.vBar.alpha = 0.6
    @add @morphsList

    # close button
    @buttonClose = new TriggerMorph(@)
    @buttonClose.setLabel "close"
    @buttonClose.action = =>
      @destroy()

    @add @buttonClose

    # resizer
    @resizer = new HandleMorph(@, 150, 100, @edge, @edge)

    # update layout
    @layoutSubmorphs()
  
  layoutSubmorphs: ->
    Morph::trackChanges = false

    # label
    x = @left() + @edge
    y = @top() + @edge
    r = @right() - @edge
    w = r - x
    @label.setPosition new Point(x, y)
    @label.setWidth w
    if @label.height() > (@height() - 50)
      @setHeight @label.height() + 50
      @changed()
      #@resizer.updateRendering()

    # morphsList
    y = @label.bottom() + 2
    w = @width() - @edge
    w -= @edge
    b = @bottom() - (2 * @edge) - WorldMorph.preferencesAndSettings.handleSize
    h = b - y
    @morphsList.setPosition new Point(x, y)
    @morphsList.setExtent new Point(w, h)

    # close button
    x = @morphsList.left()
    y = @morphsList.bottom() + @edge
    h = WorldMorph.preferencesAndSettings.handleSize
    w = @morphsList.width() - h - @edge
    @buttonClose.setPosition new Point(x, y)
    @buttonClose.setExtent new Point(w, h)
    Morph::trackChanges = true
    @changed()
  
  setExtent: (aPoint) ->
    super aPoint
    @layoutSubmorphs()

  @coffeeScriptSourceOfThisClass: '''
# MorphsListMorph //////////////////////////////////////////////////////

class MorphsListMorph extends BoxMorph

  # panes:
  morphsList: null
  buttonClose: null
  resizer: null

  constructor: (target) ->
    super()

    @silentSetExtent new Point(
      WorldMorph.preferencesAndSettings.handleSize * 10,
      WorldMorph.preferencesAndSettings.handleSize * 20 * 2 / 3)
    @isDraggable = true
    @border = 1
    @edge = 5
    @color = new Color(60, 60, 60)
    @borderColor = new Color(95, 95, 95)
    @buildAndConnectChildren()
  
  setTarget: (target) ->
    @target = target
    @currentProperty = null
    @buildAndConnectChildren()
  
  buildAndConnectChildren: ->
    attribs = []

    # remove existing panes
    @destroyAll()

    @children = []

    # label
    @label = new TextMorph("Morphs List")
    @label.fontSize = WorldMorph.preferencesAndSettings.menuFontSize
    @label.isBold = true
    @label.color = new Color(255, 255, 255)
    @add @label

    # Check which objects end with the word Morph
    theWordMorph = "Morph"
    ListOfMorphs = (Object.keys(window)).filter (i) ->
      i.indexOf(theWordMorph, i.length - theWordMorph.length) isnt -1
    @morphsList = new ListMorph(ListOfMorphs, null)

    # so far nothing happens when items are selected
    #@morphsList.action = (selected) ->
    #  val = myself.target[selected]
    #  myself.currentProperty = val
    #  if val is null
    #    txt = "NULL"
    #  else if isString(val)
    #    txt = val
    #  else
    #    txt = val.toString()
    #  cnts = new TextMorph(txt)
    #  cnts.isEditable = true
    #  cnts.enableSelecting()
    #  cnts.setReceiver myself.target
    #  myself.detail.setContents cnts

    @morphsList.hBar.alpha = 0.6
    @morphsList.vBar.alpha = 0.6
    @add @morphsList

    # close button
    @buttonClose = new TriggerMorph(@)
    @buttonClose.setLabel "close"
    @buttonClose.action = =>
      @destroy()

    @add @buttonClose

    # resizer
    @resizer = new HandleMorph(@, 150, 100, @edge, @edge)

    # update layout
    @layoutSubmorphs()
  
  layoutSubmorphs: ->
    Morph::trackChanges = false

    # label
    x = @left() + @edge
    y = @top() + @edge
    r = @right() - @edge
    w = r - x
    @label.setPosition new Point(x, y)
    @label.setWidth w
    if @label.height() > (@height() - 50)
      @setHeight @label.height() + 50
      @changed()
      #@resizer.updateRendering()

    # morphsList
    y = @label.bottom() + 2
    w = @width() - @edge
    w -= @edge
    b = @bottom() - (2 * @edge) - WorldMorph.preferencesAndSettings.handleSize
    h = b - y
    @morphsList.setPosition new Point(x, y)
    @morphsList.setExtent new Point(w, h)

    # close button
    x = @morphsList.left()
    y = @morphsList.bottom() + @edge
    h = WorldMorph.preferencesAndSettings.handleSize
    w = @morphsList.width() - h - @edge
    @buttonClose.setPosition new Point(x, y)
    @buttonClose.setExtent new Point(w, h)
    Morph::trackChanges = true
    @changed()
  
  setExtent: (aPoint) ->
    super aPoint
    @layoutSubmorphs()
  '''

# MouseSensorMorph ////////////////////////////////////////////////////

# for demo and debuggin purposes only, to be removed later
class MouseSensorMorph extends BoxMorph
  constructor: (edge, border, borderColor) ->
    super
    @edge = edge or 4
    @border = border or 2
    @color = new Color(255, 255, 255)
    @borderColor = borderColor or new Color()
    @isTouched = false
    @upStep = 0.05
    @downStep = 0.02
    @noticesTransparentClick = false
  
  touch: ->
    unless @isTouched
      @isTouched = true
      @alpha = 0.6
      @step = =>
        if @isTouched
          @alpha = @alpha + @upStep  if @alpha < 1
        else if @alpha > (@downStep)
          @alpha = @alpha - @downStep
        else
          @alpha = 0
          @step = null
        @changed()
  
  unTouch: ->
    @isTouched = false
  
  mouseEnter: ->
    @touch()
  
  mouseLeave: ->
    @unTouch()
  
  mouseDownLeft: ->
    @touch()
  
  mouseClickLeft: ->
    @unTouch()

  @coffeeScriptSourceOfThisClass: '''
# MouseSensorMorph ////////////////////////////////////////////////////

# for demo and debuggin purposes only, to be removed later
class MouseSensorMorph extends BoxMorph
  constructor: (edge, border, borderColor) ->
    super
    @edge = edge or 4
    @border = border or 2
    @color = new Color(255, 255, 255)
    @borderColor = borderColor or new Color()
    @isTouched = false
    @upStep = 0.05
    @downStep = 0.02
    @noticesTransparentClick = false
  
  touch: ->
    unless @isTouched
      @isTouched = true
      @alpha = 0.6
      @step = =>
        if @isTouched
          @alpha = @alpha + @upStep  if @alpha < 1
        else if @alpha > (@downStep)
          @alpha = @alpha - @downStep
        else
          @alpha = 0
          @step = null
        @changed()
  
  unTouch: ->
    @isTouched = false
  
  mouseEnter: ->
    @touch()
  
  mouseLeave: ->
    @unTouch()
  
  mouseDownLeft: ->
    @touch()
  
  mouseClickLeft: ->
    @unTouch()
  '''

###
Copyright 2013 Craig Campbell
coffeescript port by Davide Della Casa

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Mousetrap is a simple keyboard shortcut library for Javascript with
no external dependencies

@version 1.3.1
@url craig.is/killing/mice
###

###
mapping of special keycodes to their corresponding keys

everything in this dictionary cannot use keypress events
so it has to be here to map to the correct keycodes for
keyup/keydown events

@type {Object}
###

_MAP =
  8: "backspace"
  9: "tab"
  13: "enter"
  16: "shift"
  17: "ctrl"
  18: "alt"
  20: "capslock"
  27: "esc"
  32: "space"
  33: "pageup"
  34: "pagedown"
  35: "end"
  36: "home"
  37: "left"
  38: "up"
  39: "right"
  40: "down"
  45: "ins"
  46: "del"
  91: "meta"
  93: "meta"
  224: "meta"

###
mapping for special characters so they can support

this dictionary is only used incase you want to bind a
keyup or keydown event to one of these keys

@type {Object}
###
_KEYCODE_MAP =
  106: "*"
  107: "+"
  109: "-"
  110: "."
  111: "/"
  186: ";"
  187: "="
  188: ","
  189: "-"
  190: "."
  191: "/"
  192: "`"
  219: "["
  220: "\\"
  221: "]"
  222: "'"

###
this is a mapping of keys that require shift on a US keypad
back to the non shift equivelents

this is so you can use keyup events with these keys

note that this will only work reliably on US keyboards

@type {Object}
###
_SHIFT_MAP =
  "~": "`"
  "!": "1"
  "@": "2"
  "#": "3"
  $: "4"
  "%": "5"
  "^": "6"
  "&": "7"
  "*": "8"
  "(": "9"
  ")": "0"
  _: "-"
  "+": "="
  ":": ";"
  "\"": "'"
  "<": ","
  ">": "."
  "?": "/"
  "|": "\\"

###
this is a list of special strings you can use to map
to modifier keys when you specify your keyboard shortcuts

@type {Object}
###
_SPECIAL_ALIASES =
  option: "alt"
  command: "meta"
  return: "enter"
  escape: "esc"

###
variable to store the flipped version of _MAP from above
needed to check if we should use keypress or not when no action
is specified

@type {Object|undefined}
###
_REVERSE_MAP = undefined

###
a list of all the callbacks setup via Mousetrap.bind()

@type {Object}
###
_callbacks = {}

###
direct map of string combinations to callbacks used for trigger()

@type {Object}
###
_directMap = {}

###
keeps track of what level each sequence is at since multiple
sequences can start out with the same sequence

@type {Object}
###
_sequenceLevels = {}

###
variable to store the setTimeout call

@type {null|number}
###
_resetTimer = undefined

###
temporary state where we will ignore the next keyup

@type {boolean|string}
###
_ignoreNextKeyup = false

###
are we currently inside of a sequence?
type of action ("keyup" or "keydown" or "keypress") or false

@type {boolean|string}
###
_sequenceType = false

###
loop through the f keys, f1 to f19 and add them to the map
programatically
###
i = 1
while i < 20
  _MAP[111 + i] = "f" + i
  ++i

###
loop through to map numbers on the numeric keypad
###
i = 0
while i <= 9
  _MAP[i + 96] = i
  ++i


###
cross browser add event method

@param {Element|HTMLDocument} object
@param {string} type
@param {Function} callback
@returns void
###
_addEvent = (object, type, callback) ->
  if object.addEventListener
    object.addEventListener type, callback, false
    return
  object.attachEvent "on" + type, callback

###
takes the event and returns the key character

@param {Event} e
@return {string}
###
_characterFromEvent = (e) ->
  
  # for keypress events we should return the character as is
  return String.fromCharCode(e.which)  if e.type is "keypress"
  
  # for non keypress events the special maps are needed
  return _MAP[e.which]  if _MAP[e.which]
  return _KEYCODE_MAP[e.which]  if _KEYCODE_MAP[e.which]
  
  # if it is not in the special map
  String.fromCharCode(e.which).toLowerCase()

###
checks if two arrays are equal

@param {Array} modifiers1
@param {Array} modifiers2
@returns {boolean}
###
_modifiersMatch = (modifiers1, modifiers2) ->
  modifiers1.sort().join(",") is modifiers2.sort().join(",")

###
resets all sequence counters except for the ones passed in

@param {Object} doNotReset
@returns void
###
_resetSequences = (doNotReset, maxLevel) ->
  doNotReset = doNotReset or {}
  activeSequences = false
  key = undefined
  for key of _sequenceLevels
    if doNotReset[key] and _sequenceLevels[key] > maxLevel
      activeSequences = true
      continue
    _sequenceLevels[key] = 0
  _sequenceType = false  unless activeSequences

###
finds all callbacks that match based on the keycode, modifiers,
and action

@param {string} character
@param {Array} modifiers
@param {Event|Object} e
@param {boolean=} remove - should we remove any matches
@param {string=} combination
@returns {Array}
###
_getMatches = (character, modifiers, e, remove, combination) ->
  i = undefined
  callback = undefined
  matches = []
  action = e.type
  
  # if there are no events related to this keycode
  return []  unless _callbacks[character]
  
  # if a modifier key is coming up on its own we should allow it
  modifiers = [character]  if action is "keyup" and _isModifier(character)
  
  # loop through all callbacks for the key that was pressed
  # and see if any of them match
  for i in [0..._callbacks[character].length]
    callback = _callbacks[character][i]
    
    # if this is a sequence but it is not at the right level
    # then move onto the next match
    continue  if callback.seq and _sequenceLevels[callback.seq] isnt callback.level
    
    # if the action we are looking for doesn't match the action we got
    # then we should keep going
    continue  unless action is callback.action
    
    # if this is a keypress event and the meta key and control key
    # are not pressed that means that we need to only look at the
    # character, otherwise check the modifiers as well
    #
    # chrome will not fire a keypress if meta or control is down
    # safari will fire a keypress if meta or meta+shift is down
    # firefox will fire a keypress if meta or control is down
    if (action is "keypress" and not e.metaKey and not e.ctrlKey) or _modifiersMatch(modifiers, callback.modifiers)
      
      # remove is used so if you change your mind and call bind a
      # second time with a new function the first one is overwritten
      _callbacks[character].splice i, 1  if remove and callback.combo is combination
      matches.push callback
  matches

###
takes a key event and figures out what the modifiers are

@param {Event} e
@returns {Array}
###
_eventModifiers = (e) ->
  modifiers = []
  modifiers.push "shift"  if e.shiftKey
  modifiers.push "alt"  if e.altKey
  modifiers.push "ctrl"  if e.ctrlKey
  modifiers.push "meta"  if e.metaKey
  modifiers

###
actually calls the callback function

if your callback function returns false this will use the jquery
convention - prevent default and stop propogation on the event

@param {Function} callback
@param {Event} e
@returns void
###
_fireCallback = (callback, e, combo) ->
  
  # if this event should not happen stop here
  return  if Mousetrap.stopCallback(e, e.target or e.srcElement, combo)
  if callback(e, combo) is false
    e.preventDefault()  if e.preventDefault
    e.stopPropagation()  if e.stopPropagation
    e.returnValue = false
    e.cancelBubble = true

###
handles a character key event

@param {string} character
@param {Event} e
@returns void
###
_handleCharacter = (character, e) ->
  callbacks = _getMatches(character, _eventModifiers(e), e)
  i = undefined
  doNotReset = {}
  maxLevel = 0
  processedSequenceCallback = false
  
  # loop through matching callbacks for this key event
  i = 0
  while i < callbacks.length
    
    # fire for all sequence callbacks
    # this is because if for example you have multiple sequences
    # bound such as "g i" and "g t" they both need to fire the
    # callback for matching g cause otherwise you can only ever
    # match the first one
    if callbacks[i].seq
      processedSequenceCallback = true
      
      # as we loop through keep track of the max
      # any sequence at a lower level will be discarded
      maxLevel = Math.max(maxLevel, callbacks[i].level)
      
      # keep a list of which sequences were matches for later
      doNotReset[callbacks[i].seq] = 1
      _fireCallback callbacks[i].callback, e, callbacks[i].combo
      continue
    
    # if there were no sequence matches but we are still here
    # that means this is a regular match so we should fire that
    _fireCallback callbacks[i].callback, e, callbacks[i].combo  if not processedSequenceCallback and not _sequenceType
    ++i
  
  # if you are inside of a sequence and the key you are pressing
  # is not a modifier key then we should reset all sequences
  # that were not matched by this key event
  _resetSequences doNotReset, maxLevel  if e.type is _sequenceType and not _isModifier(character)

###
handles a keydown event

@param {Event} e
@returns void
###
_handleKey = (e) ->
  
  # normalize e.which for key events
  # @see http://stackoverflow.com/questions/4285627/javascript-keycode-vs-charcode-utter-confusion
  e.which = e.keyCode  if typeof e.which isnt "number"
  character = _characterFromEvent(e)
  
  # no character found then stop
  return  unless character
  if e.type is "keyup" and _ignoreNextKeyup is character
    _ignoreNextKeyup = false
    return
  _handleCharacter character, e

###
determines if the keycode specified is a modifier key or not

@param {string} key
@returns {boolean}
###
_isModifier = (key) ->
  key is "shift" or key is "ctrl" or key is "alt" or key is "meta"

###
called to set a 1 second timeout on the specified sequence

this is so after each key press in the sequence you have 1 second
to press the next key before you have to start over

@returns void
###
_resetSequenceTimer = ->
  clearTimeout _resetTimer
  _resetTimer = setTimeout(_resetSequences, 1000)

###
reverses the map lookup so that we can look for specific keys
to see what can and can't use keypress

@return {Object}
###
_getReverseMap = ->
  unless _REVERSE_MAP
    _REVERSE_MAP = {}
    for key of _MAP
      
      # pull out the numeric keypad from here cause keypress should
      # be able to detect the keys from the character
      continue  if key > 95 and key < 112
      _REVERSE_MAP[_MAP[key]] = key  if _MAP.hasOwnProperty(key)
  _REVERSE_MAP

###
picks the best action based on the key combination

@param {string} key - character for key
@param {Array} modifiers
@param {string=} action passed in
###
_pickBestAction = (key, modifiers, action) ->
  
  # if no action was picked in we should try to pick the one
  # that we think would work best for this key
  action = (if _getReverseMap()[key] then "keydown" else "keypress")  unless action
  
  # modifier keys don't work as expected with keypress,
  # switch to keydown
  action = "keydown"  if action is "keypress" and modifiers.length
  action

###
binds a key sequence to an event

@param {string} combo - combo specified in bind call
@param {Array} keys
@param {Function} callback
@param {string=} action
@returns void
###
_bindSequence = (combo, keys, callback, action) ->
  
  # start off by adding a sequence level record for this combination
  # and setting the level to 0
  _sequenceLevels[combo] = 0
  
  # if there is no action pick the best one for the first key
  # in the sequence
  action = _pickBestAction(keys[0], [])  unless action
  
  ###
  callback to increase the sequence level for this sequence and reset
  all other sequences that were active
  
  @param {Event} e
  @returns void
  ###
  _increaseSequence = ->
    _sequenceType = action
    ++_sequenceLevels[combo]
    _resetSequenceTimer()

  
  ###
  wraps the specified callback inside of another function in order
  to reset all sequence counters as soon as this sequence is done
  
  @param {Event} e
  @returns void
  ###
  _callbackAndReset = (e) ->
    _fireCallback callback, e, combo
    
    # we should ignore the next key up if the action is key down
    # or keypress.  this is so if you finish a sequence and
    # release the key the final key will not trigger a keyup
    _ignoreNextKeyup = _characterFromEvent(e)  if action isnt "keyup"
    
    # weird race condition if a sequence ends with the key
    # another sequence begins with
    setTimeout _resetSequences, 10

  i = undefined
  
  # loop through keys one at a time and bind the appropriate callback
  # function.  for any key leading up to the final one it should
  # increase the sequence. after the final, it should reset all sequences
  i = 0
  while i < keys.length
    _bindSingle keys[i], (if i < keys.length - 1 then _increaseSequence else _callbackAndReset), action, combo, i
    ++i

###
binds a single keyboard combination

@param {string} combination
@param {Function} callback
@param {string=} action
@param {string=} sequenceName - name of sequence if part of sequence
@param {number=} level - what part of the sequence the command is
@returns void
###
_bindSingle = (combination, callback, action, sequenceName, level) ->
  
  # store a direct mapped reference for use with Mousetrap.trigger
  _directMap[combination + ":" + action] = callback
  
  # make sure multiple spaces in a row become a single space
  combination = combination.replace(/\s+/g, " ")
  sequence = combination.split(" ")
  i = undefined
  key = undefined
  keys = undefined
  modifiers = []
  
  # if this pattern is a sequence of keys then run through this method
  # to reprocess each pattern one key at a time
  if sequence.length > 1
    _bindSequence combination, sequence, callback, action
    return
  
  # take the keys from this pattern and figure out what the actual
  # pattern is all about
  keys = (if combination is "+" then ["+"] else combination.split("+"))
  i = 0
  while i < keys.length
    key = keys[i]
    
    # normalize key names
    key = _SPECIAL_ALIASES[key]  if _SPECIAL_ALIASES[key]
    
    # if this is not a keypress event then we should
    # be smart about using shift keys
    # this will only work for US keyboards however
    if action and action isnt "keypress" and _SHIFT_MAP[key]
      key = _SHIFT_MAP[key]
      modifiers.push "shift"
    
    # if this key is a modifier then add it to the list of modifiers
    modifiers.push key  if _isModifier(key)
    ++i
  
  # depending on what the key combination is
  # we will try to pick the best event for it
  action = _pickBestAction(key, modifiers, action)
  
  # make sure to initialize array if this is the first time
  # a callback is added for this key
  _callbacks[key] = []  unless _callbacks[key]
  
  # remove an existing match if there is one
  _getMatches key, modifiers,
    type: action
  , not sequenceName, combination
  
  # add this call back to the array
  # if it is a sequence put it at the beginning
  # if not put it at the end
  #
  # this is important because the way these are processed expects
  # the sequence ones to come first
  _callbacks[key][(if sequenceName then "unshift" else "push")]
    callback: callback
    modifiers: modifiers
    action: action
    seq: sequenceName
    level: level
    combo: combination


###
binds multiple combinations to the same callback

@param {Array} combinations
@param {Function} callback
@param {string|undefined} action
@returns void
###
_bindMultiple = (combinations, callback, action) ->
  i = 0

  while i < combinations.length
    _bindSingle combinations[i], callback, action
    ++i


# start!
_addEvent document, "keypress", _handleKey
_addEvent document, "keydown", _handleKey
_addEvent document, "keyup", _handleKey
Mousetrap =
  
  ###
  binds an event to mousetrap
  
  can be a single key, a combination of keys separated with +,
  an array of keys, or a sequence of keys separated by spaces
  
  be sure to list the modifier keys first to make sure that the
  correct key ends up getting bound (the last key in the pattern)
  
  @param {string|Array} keys
  @param {Function} callback
  @param {string=} action - 'keypress', 'keydown', or 'keyup'
  @returns void
  ###
  bind: (keys, callback, action) ->
    keys = (if keys instanceof Array then keys else [keys])
    _bindMultiple keys, callback, action
    this

  
  ###
  unbinds an event to mousetrap
  
  the unbinding sets the callback function of the specified key combo
  to an empty function and deletes the corresponding key in the
  _directMap dict.
  
  TODO: actually remove this from the _callbacks dictionary instead
  of binding an empty function
  
  the keycombo+action has to be exactly the same as
  it was defined in the bind method
  
  @param {string|Array} keys
  @param {string} action
  @returns void
  ###
  unbind: (keys, action) ->
    Mousetrap.bind keys, (->
    ), action

  
  ###
  triggers an event that has already been bound
  
  @param {string} keys
  @param {string=} action
  @returns void
  ###
  trigger: (keys, action) ->
    _directMap[keys + ":" + action] {}, keys  if _directMap[keys + ":" + action]
    this

  
  ###
  resets the library back to its initial state.  this is useful
  if you want to clear out the current keyboard shortcuts and bind
  new ones - for example if you switch to another page
  
  @returns void
  ###
  reset: ->
    _callbacks = {}
    _directMap = {}
    this

  
  ###
  should we stop this event before firing off callbacks
  
  @param {Event} e
  @param {Element} element
  @return {boolean}
  ###
  stopCallback: (e, element) ->
    
    # if the element has the class "mousetrap" then no need to stop
    return false  if (" " + element.className + " ").indexOf(" mousetrap ") > -1
    
    # stop for input, select, and textarea
    element.tagName is "INPUT" or element.tagName is "SELECT" or element.tagName is "TEXTAREA" or (element.contentEditable and element.contentEditable is "true")

window.Mousetrap = Mousetrap

# PenMorph ////////////////////////////////////////////////////////////

# I am a simple LOGO-wise turtle.

class PenMorph extends Morph
  
  heading: 0
  penSize: null
  isWarped: false # internal optimization
  isDown: true
  wantsRedraw: false # internal optimization
  penPoint: 'tip' # or 'center'
  
  constructor: ->
    @penSize = WorldMorph.preferencesAndSettings.handleSize * 4
    super()
    @setExtent new Point(@penSize, @penSize)
    # todo we need to change the size two times, for getting the right size
    # of the arrow and of the line. Probably should make the two distinct
    @penSize = 1
    #alert @morphMethod() # works
    # doesn't work cause coffeescript doesn't support static inheritance
    #alert @morphStaticMethod()

    # no need to call @updateRendering() because @setExtent does it.
    # (should it?)
    #@updateRendering()


  @staticVariable: 1
  @staticFunction: -> 3.14
    
  # PenMorph updating - optimized for warping, i.e atomic recursion
  changed: ->
    if @isWarped is false
      w = @root()
      # unless we are the main desktop, then if the morph has no parent
      # don't add the broken rect since the morph is not visible
      if w instanceof WorldMorph and (@ instanceof WorldMorph or @parent?)
        w.broken.push @visibleBounds().spread()
      @parent.childChanged @  if @parent
  
  
  # PenMorph display:
  updateRendering: (facing) ->
    #
    #    my orientation can be overridden with the "facing" parameter to
    #    implement Scratch-style rotation styles
    #    
    #
    direction = facing or @heading
    if @isWarped
      @wantsRedraw = true
      return
    @image = newCanvas(@extent().scaleBy pixelRatio)
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    len = @width() / 2
    start = @center().subtract(@bounds.origin)

    if @penPoint is "tip"
      dest = start.distanceAngle(len * 0.75, direction - 180)
      left = start.distanceAngle(len, direction + 195)
      right = start.distanceAngle(len, direction - 195)
    else # 'middle'
      dest = start.distanceAngle(len * 0.75, direction)
      left = start.distanceAngle(len * 0.33, direction + 230)
      right = start.distanceAngle(len * 0.33, direction - 230)

    context.fillStyle = @color.toString()
    context.beginPath()

    context.moveTo start.x, start.y
    context.lineTo left.x, left.y
    context.lineTo dest.x, dest.y
    context.lineTo right.x, right.y

    context.closePath()
    context.strokeStyle = "white"
    context.lineWidth = 3
    context.stroke()
    context.strokeStyle = "black"
    context.lineWidth = 1
    context.stroke()
    context.fill()
    @wantsRedraw = false
  
  
  # PenMorph access:
  setHeading: (degrees) ->
    @heading = parseFloat(degrees) % 360
    @updateRendering()
    @changed()
  
  
  # PenMorph drawing:
  drawLine: (start, dest) ->
    context = @parent.penTrails().getContext("2d")
    # by default penTrails() is to answer the normal
    # morph image.
    # The implication is that by default every Morph in the system
    # (including the World) is able to act as turtle canvas and can
    # display pen trails.
    # BUT also this means that pen trails will be lost whenever
    # the trail's morph (the pen's parent) performs a "drawNew()"
    # operation. If you want to create your own pen trails canvas,
    # you may wish to modify its **penTrails()** property, so that
    # it keeps a separate offscreen canvas for pen trails
    # (and doesn't lose these on redraw).

    from = start.subtract(@parent.bounds.origin)
    to = dest.subtract(@parent.bounds.origin)
    if @isDown
      context.lineWidth = @penSize
      context.strokeStyle = @color.toString()
      context.lineCap = "round"
      context.lineJoin = "round"
      context.beginPath()
      context.moveTo from.x, from.y
      context.lineTo to.x, to.y
      context.stroke()
      # unless we are the main desktop, then if the morph has no parent
      # don't add the broken rect since the morph is not visible
      if @isWarped is false and (@ instanceof WorldMorph or @parent?)
        @world().broken.push start.rectangle(dest).expandBy(Math.max(@penSize / 2, 1)).intersect(@parent.visibleBounds()).spread()
  
  
  # PenMorph turtle ops:
  turn: (degrees) ->
    @setHeading @heading + parseFloat(degrees)
  
  forward: (steps) ->
    start = @center()
    dist = parseFloat(steps)
    if dist >= 0
      dest = @position().distanceAngle(dist, @heading)
    else
      dest = @position().distanceAngle(Math.abs(dist), (@heading - 180))
    @setPosition dest
    @drawLine start, @center()
  
  down: ->
    @isDown = true
  
  up: ->
    @isDown = false
  
  clear: ->
    @parent.updateRendering()
    @parent.changed()
  
  
  # PenMorph optimization for atomic recursion:
  startWarp: ->
    @wantsRedraw = false
    @isWarped = true
  
  endWarp: ->
    @isWarped = false
    if @wantsRedraw
      @updateRendering()
      @wantsRedraw = false
    @parent.changed()
  
  warp: (fun) ->
    @startWarp()
    fun.call @
    @endWarp()
  
  warpOp: (selector, argsArray) ->
    @startWarp()
    @[selector].apply @, argsArray
    @endWarp()
  
  
  # PenMorph demo ops:
  # try these with WARP eg.: this.warp(function () {tree(12, 120, 20)})
  warpSierpinski: (length, min) ->
    @warpOp "sierpinski", [length, min]
  
  sierpinski: (length, min) ->
    if length > min
      for i in [0...3]
        @sierpinski length * 0.5, min
        @turn 120
        @forward length
  
  warpTree: (level, length, angle) ->
    @warpOp "tree", [level, length, angle]
  
  tree: (level, length, angle) ->
    if level > 0
      @penSize = level
      @forward length
      @turn angle
      @tree level - 1, length * 0.75, angle
      @turn angle * -2
      @tree level - 1, length * 0.75, angle
      @turn angle
      @forward -length

  @coffeeScriptSourceOfThisClass: '''
# PenMorph ////////////////////////////////////////////////////////////

# I am a simple LOGO-wise turtle.

class PenMorph extends Morph
  
  heading: 0
  penSize: null
  isWarped: false # internal optimization
  isDown: true
  wantsRedraw: false # internal optimization
  penPoint: 'tip' # or 'center'
  
  constructor: ->
    @penSize = WorldMorph.preferencesAndSettings.handleSize * 4
    super()
    @setExtent new Point(@penSize, @penSize)
    # todo we need to change the size two times, for getting the right size
    # of the arrow and of the line. Probably should make the two distinct
    @penSize = 1
    #alert @morphMethod() # works
    # doesn't work cause coffeescript doesn't support static inheritance
    #alert @morphStaticMethod()

    # no need to call @updateRendering() because @setExtent does it.
    # (should it?)
    #@updateRendering()


  @staticVariable: 1
  @staticFunction: -> 3.14
    
  # PenMorph updating - optimized for warping, i.e atomic recursion
  changed: ->
    if @isWarped is false
      w = @root()
      # unless we are the main desktop, then if the morph has no parent
      # don't add the broken rect since the morph is not visible
      if w instanceof WorldMorph and (@ instanceof WorldMorph or @parent?)
        w.broken.push @visibleBounds().spread()
      @parent.childChanged @  if @parent
  
  
  # PenMorph display:
  updateRendering: (facing) ->
    #
    #    my orientation can be overridden with the "facing" parameter to
    #    implement Scratch-style rotation styles
    #    
    #
    direction = facing or @heading
    if @isWarped
      @wantsRedraw = true
      return
    @image = newCanvas(@extent().scaleBy pixelRatio)
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    len = @width() / 2
    start = @center().subtract(@bounds.origin)

    if @penPoint is "tip"
      dest = start.distanceAngle(len * 0.75, direction - 180)
      left = start.distanceAngle(len, direction + 195)
      right = start.distanceAngle(len, direction - 195)
    else # 'middle'
      dest = start.distanceAngle(len * 0.75, direction)
      left = start.distanceAngle(len * 0.33, direction + 230)
      right = start.distanceAngle(len * 0.33, direction - 230)

    context.fillStyle = @color.toString()
    context.beginPath()

    context.moveTo start.x, start.y
    context.lineTo left.x, left.y
    context.lineTo dest.x, dest.y
    context.lineTo right.x, right.y

    context.closePath()
    context.strokeStyle = "white"
    context.lineWidth = 3
    context.stroke()
    context.strokeStyle = "black"
    context.lineWidth = 1
    context.stroke()
    context.fill()
    @wantsRedraw = false
  
  
  # PenMorph access:
  setHeading: (degrees) ->
    @heading = parseFloat(degrees) % 360
    @updateRendering()
    @changed()
  
  
  # PenMorph drawing:
  drawLine: (start, dest) ->
    context = @parent.penTrails().getContext("2d")
    # by default penTrails() is to answer the normal
    # morph image.
    # The implication is that by default every Morph in the system
    # (including the World) is able to act as turtle canvas and can
    # display pen trails.
    # BUT also this means that pen trails will be lost whenever
    # the trail's morph (the pen's parent) performs a "drawNew()"
    # operation. If you want to create your own pen trails canvas,
    # you may wish to modify its **penTrails()** property, so that
    # it keeps a separate offscreen canvas for pen trails
    # (and doesn't lose these on redraw).

    from = start.subtract(@parent.bounds.origin)
    to = dest.subtract(@parent.bounds.origin)
    if @isDown
      context.lineWidth = @penSize
      context.strokeStyle = @color.toString()
      context.lineCap = "round"
      context.lineJoin = "round"
      context.beginPath()
      context.moveTo from.x, from.y
      context.lineTo to.x, to.y
      context.stroke()
      # unless we are the main desktop, then if the morph has no parent
      # don't add the broken rect since the morph is not visible
      if @isWarped is false and (@ instanceof WorldMorph or @parent?)
        @world().broken.push start.rectangle(dest).expandBy(Math.max(@penSize / 2, 1)).intersect(@parent.visibleBounds()).spread()
  
  
  # PenMorph turtle ops:
  turn: (degrees) ->
    @setHeading @heading + parseFloat(degrees)
  
  forward: (steps) ->
    start = @center()
    dist = parseFloat(steps)
    if dist >= 0
      dest = @position().distanceAngle(dist, @heading)
    else
      dest = @position().distanceAngle(Math.abs(dist), (@heading - 180))
    @setPosition dest
    @drawLine start, @center()
  
  down: ->
    @isDown = true
  
  up: ->
    @isDown = false
  
  clear: ->
    @parent.updateRendering()
    @parent.changed()
  
  
  # PenMorph optimization for atomic recursion:
  startWarp: ->
    @wantsRedraw = false
    @isWarped = true
  
  endWarp: ->
    @isWarped = false
    if @wantsRedraw
      @updateRendering()
      @wantsRedraw = false
    @parent.changed()
  
  warp: (fun) ->
    @startWarp()
    fun.call @
    @endWarp()
  
  warpOp: (selector, argsArray) ->
    @startWarp()
    @[selector].apply @, argsArray
    @endWarp()
  
  
  # PenMorph demo ops:
  # try these with WARP eg.: this.warp(function () {tree(12, 120, 20)})
  warpSierpinski: (length, min) ->
    @warpOp "sierpinski", [length, min]
  
  sierpinski: (length, min) ->
    if length > min
      for i in [0...3]
        @sierpinski length * 0.5, min
        @turn 120
        @forward length
  
  warpTree: (level, length, angle) ->
    @warpOp "tree", [level, length, angle]
  
  tree: (level, length, angle) ->
    if level > 0
      @penSize = level
      @forward length
      @turn angle
      @tree level - 1, length * 0.75, angle
      @turn angle * -2
      @tree level - 1, length * 0.75, angle
      @turn angle
      @forward -length
  '''

# Point2 //////////////////////////////////////////////////////////////
# like Point, but it tries not to create new objects like there is
# no tomorrow. Any operation that returned a new point now directly
# modifies the current point.
# Note that the arguments passed to any of these functions are never
# modified.

class Point2

  x: null
  y: null
   
  constructor: (@x = 0, @y = 0) ->
  
  # Point2 string representation: e.g. '12@68'
  toString: ->
    Math.round(@x) + "@" + Math.round(@y)
  
  # Point2 copying:
  copy: ->
    new @constructor(@x, @y)
  
  # Point2 comparison:
  eq: (aPoint2) ->
    # ==
    @x is aPoint2.x and @y is aPoint2.y
  
  lt: (aPoint2) ->
    # <
    @x < aPoint2.x and @y < aPoint2.y
  
  gt: (aPoint2) ->
    # >
    @x > aPoint2.x and @y > aPoint2.y
  
  ge: (aPoint2) ->
    # >=
    @x >= aPoint2.x and @y >= aPoint2.y
  
  le: (aPoint2) ->
    # <=
    @x <= aPoint2.x and @y <= aPoint2.y
  
  max: (aPoint2) ->
    #new @constructor(Math.max(@x, aPoint2.x), Math.max(@y, aPoint2.y))
    @x = Math.max(@x, aPoint2.x)
    @y = Math.max(@y, aPoint2.y)
  
  min: (aPoint2) ->
    #new @constructor(Math.min(@x, aPoint2.x), Math.min(@y, aPoint2.y))
    @x = Math.min(@x, aPoint2.x)
    @y = Math.min(@y, aPoint2.y)
  
  
  # Point2 conversion:
  round: ->
    #new @constructor(Math.round(@x), Math.round(@y))
    @x = Math.round(@x)
    @y = Math.round(@y)
  
  abs: ->
    #new @constructor(Math.abs(@x), Math.abs(@y))
    @x = Math.abs(@x)
    @y = Math.abs(@y)
  
  neg: ->
    #new @constructor(-@x, -@y)
    @x = -@x
    @y = -@y
  
  mirror: ->
    #new @constructor(@y, @x)
    # note that coffeescript would allow [@x,@y] = [@y,@x]
    # but we want to be faster here
    tmpValueForSwappingXAndY = @x
    @x = @y
    @y = tmpValueForSwappingXAndY 
  
  floor: ->
    #new @constructor(Math.max(Math.floor(@x), 0), Math.max(Math.floor(@y), 0))
    @x = Math.max(Math.floor(@x), 0)
    @y = Math.max(Math.floor(@y), 0)
  
  ceil: ->
    #new @constructor(Math.ceil(@x), Math.ceil(@y))
    @x = Math.ceil(@x)
    @y = Math.ceil(@y)
  
  
  # Point2 arithmetic:
  add: (other) ->
    if other instanceof Point2
      @x = @x + other.x
      @y = @y + other.y
      return
    @x = @x + other
    @y = @y + other
  
  subtract: (other) ->
    if other instanceof Point2
      @x = @x - other.x
      @y = @y - other.y
      return
    @x = @x - other
    @y = @y - other
  
  multiplyBy: (other) ->
    if other instanceof Point2
      @x = @x * other.x
      @y = @y * other.y
      return
    @x = @x * other
    @y = @y * other
  
  divideBy: (other) ->
    if other instanceof Point2
      @x = @x / other.x
      @y = @y / other.y
      return
    @x = @x / other
    @y = @y / other
  
  floorDivideBy: (other) ->
    if other instanceof Point2
      @x = Math.floor(@x / other.x)
      @y = Math.floor(@y / other.y)
      return
    @x = Math.floor(@x / other)
    @y = Math.floor(@y / other)
  
  
  # Point2 polar coordinates:
  # distance from the origin
  r: ->
    t = @copy()
    t.multiplyBy(t)
    Math.sqrt t.x + t.y
  
  degrees: ->
    #
    #    answer the angle I make with origin in degrees.
    #    Right is 0, down is 90
    #
    if @x is 0
      return 90  if @y >= 0
      return 270
    tan = @y / @x
    theta = Math.atan(tan)
    if @x >= 0
      return degrees(theta)  if @y >= 0
      return 360 + (degrees(theta))
    180 + degrees(theta)
  
  theta: ->
    #
    #    answer the angle I make with origin in radians.
    #    Right is 0, down is 90
    #
    if @x is 0
      return radians(90)  if @y >= 0
      return radians(270)
    tan = @y / @x
    theta = Math.atan(tan)
    if @x >= 0
      return theta  if @y >= 0
      return radians(360) + theta
    radians(180) + theta
  
  
  # Point2 functions:
    
  distanceTo: (aPoint2) ->
    (aPoint2.copy().subtract(@)).r()
  
  rotate: (direction, center) ->
    # direction must be 'right', 'left' or 'pi'
    offset = @copy().subtract(center)
    if direction is "right"
      @x = -offset.y + center.x
      @y = offset.y + center.y
      return
    if direction is "left"
      @x = offset.y + center.x
      @y = -offset.y + center.y
      return
    #
    # direction === 'pi'
    tmpPointForRotate = center.copy().subtract offset
    @x = tmpPointForRotate.x
    @y = tmpPointForRotate.y
  
  flip: (direction, center) ->
    # direction must be 'vertical' or 'horizontal'
    if direction is "vertical"
      @y = center.y * 2 - @y
      return
    #
    # direction === 'horizontal'
    @x = center.x * 2 - @x
  
  distanceAngle: (dist, angle) ->
    deg = angle
    if deg > 270
      deg = deg - 360
    else deg = deg + 360  if deg < -270
    if -90 <= deg and deg <= 90
      x = Math.sin(radians(deg)) * dist
      y = Math.sqrt((dist * dist) - (x * x))
      @x = x + @x
      @y = @y - y
      return
    x = Math.sin(radians(180 - deg)) * dist
    y = Math.sqrt((dist * dist) - (x * x))
    @x = x + @x
    @y = @y + y
  
  
  # Point2 transforming:
  scaleBy: (scalePoint2) ->
    @multiplyBy scalePoint2
  
  translateBy: (deltaPoint2) ->
    @add deltaPoint2
  
  rotateBy: (angle, centerPoint2) ->
    center = centerPoint2 or new @constructor(0, 0)
    p = @copy().subtract(center)
    r = p.r()
    theta = angle - p.theta()
    @x = center.x + (r * Math.cos(theta))
    @y = center.y - (r * Math.sin(theta))
  
  
  # Point2 conversion:
  asArray: ->
    [@x, @y]
  
  # creating Rectangle instances from Point2:
  corner: (cornerPoint2) ->
    # answer a new Rectangle
    new Rectangle(@x, @y, cornerPoint2.x, cornerPoint2.y)
  
  rectangle: (aPoint2) ->
    # answer a new Rectangle
    org = @copy().min(aPoint2)
    crn = @copy().max(aPoint2)
    new Rectangle(org.x, org.y, crn.x, crn.y)
  
  extent: (aPoint2) ->
    #answer a new Rectangle
    crn = @copy().add(aPoint2)
    new Rectangle(@x, @y, crn.x, crn.y)

  @coffeeScriptSourceOfThisClass: '''
# Point2 //////////////////////////////////////////////////////////////
# like Point, but it tries not to create new objects like there is
# no tomorrow. Any operation that returned a new point now directly
# modifies the current point.
# Note that the arguments passed to any of these functions are never
# modified.

class Point2

  x: null
  y: null
   
  constructor: (@x = 0, @y = 0) ->
  
  # Point2 string representation: e.g. '12@68'
  toString: ->
    Math.round(@x) + "@" + Math.round(@y)
  
  # Point2 copying:
  copy: ->
    new @constructor(@x, @y)
  
  # Point2 comparison:
  eq: (aPoint2) ->
    # ==
    @x is aPoint2.x and @y is aPoint2.y
  
  lt: (aPoint2) ->
    # <
    @x < aPoint2.x and @y < aPoint2.y
  
  gt: (aPoint2) ->
    # >
    @x > aPoint2.x and @y > aPoint2.y
  
  ge: (aPoint2) ->
    # >=
    @x >= aPoint2.x and @y >= aPoint2.y
  
  le: (aPoint2) ->
    # <=
    @x <= aPoint2.x and @y <= aPoint2.y
  
  max: (aPoint2) ->
    #new @constructor(Math.max(@x, aPoint2.x), Math.max(@y, aPoint2.y))
    @x = Math.max(@x, aPoint2.x)
    @y = Math.max(@y, aPoint2.y)
  
  min: (aPoint2) ->
    #new @constructor(Math.min(@x, aPoint2.x), Math.min(@y, aPoint2.y))
    @x = Math.min(@x, aPoint2.x)
    @y = Math.min(@y, aPoint2.y)
  
  
  # Point2 conversion:
  round: ->
    #new @constructor(Math.round(@x), Math.round(@y))
    @x = Math.round(@x)
    @y = Math.round(@y)
  
  abs: ->
    #new @constructor(Math.abs(@x), Math.abs(@y))
    @x = Math.abs(@x)
    @y = Math.abs(@y)
  
  neg: ->
    #new @constructor(-@x, -@y)
    @x = -@x
    @y = -@y
  
  mirror: ->
    #new @constructor(@y, @x)
    # note that coffeescript would allow [@x,@y] = [@y,@x]
    # but we want to be faster here
    tmpValueForSwappingXAndY = @x
    @x = @y
    @y = tmpValueForSwappingXAndY 
  
  floor: ->
    #new @constructor(Math.max(Math.floor(@x), 0), Math.max(Math.floor(@y), 0))
    @x = Math.max(Math.floor(@x), 0)
    @y = Math.max(Math.floor(@y), 0)
  
  ceil: ->
    #new @constructor(Math.ceil(@x), Math.ceil(@y))
    @x = Math.ceil(@x)
    @y = Math.ceil(@y)
  
  
  # Point2 arithmetic:
  add: (other) ->
    if other instanceof Point2
      @x = @x + other.x
      @y = @y + other.y
      return
    @x = @x + other
    @y = @y + other
  
  subtract: (other) ->
    if other instanceof Point2
      @x = @x - other.x
      @y = @y - other.y
      return
    @x = @x - other
    @y = @y - other
  
  multiplyBy: (other) ->
    if other instanceof Point2
      @x = @x * other.x
      @y = @y * other.y
      return
    @x = @x * other
    @y = @y * other
  
  divideBy: (other) ->
    if other instanceof Point2
      @x = @x / other.x
      @y = @y / other.y
      return
    @x = @x / other
    @y = @y / other
  
  floorDivideBy: (other) ->
    if other instanceof Point2
      @x = Math.floor(@x / other.x)
      @y = Math.floor(@y / other.y)
      return
    @x = Math.floor(@x / other)
    @y = Math.floor(@y / other)
  
  
  # Point2 polar coordinates:
  # distance from the origin
  r: ->
    t = @copy()
    t.multiplyBy(t)
    Math.sqrt t.x + t.y
  
  degrees: ->
    #
    #    answer the angle I make with origin in degrees.
    #    Right is 0, down is 90
    #
    if @x is 0
      return 90  if @y >= 0
      return 270
    tan = @y / @x
    theta = Math.atan(tan)
    if @x >= 0
      return degrees(theta)  if @y >= 0
      return 360 + (degrees(theta))
    180 + degrees(theta)
  
  theta: ->
    #
    #    answer the angle I make with origin in radians.
    #    Right is 0, down is 90
    #
    if @x is 0
      return radians(90)  if @y >= 0
      return radians(270)
    tan = @y / @x
    theta = Math.atan(tan)
    if @x >= 0
      return theta  if @y >= 0
      return radians(360) + theta
    radians(180) + theta
  
  
  # Point2 functions:
    
  distanceTo: (aPoint2) ->
    (aPoint2.copy().subtract(@)).r()
  
  rotate: (direction, center) ->
    # direction must be 'right', 'left' or 'pi'
    offset = @copy().subtract(center)
    if direction is "right"
      @x = -offset.y + center.x
      @y = offset.y + center.y
      return
    if direction is "left"
      @x = offset.y + center.x
      @y = -offset.y + center.y
      return
    #
    # direction === 'pi'
    tmpPointForRotate = center.copy().subtract offset
    @x = tmpPointForRotate.x
    @y = tmpPointForRotate.y
  
  flip: (direction, center) ->
    # direction must be 'vertical' or 'horizontal'
    if direction is "vertical"
      @y = center.y * 2 - @y
      return
    #
    # direction === 'horizontal'
    @x = center.x * 2 - @x
  
  distanceAngle: (dist, angle) ->
    deg = angle
    if deg > 270
      deg = deg - 360
    else deg = deg + 360  if deg < -270
    if -90 <= deg and deg <= 90
      x = Math.sin(radians(deg)) * dist
      y = Math.sqrt((dist * dist) - (x * x))
      @x = x + @x
      @y = @y - y
      return
    x = Math.sin(radians(180 - deg)) * dist
    y = Math.sqrt((dist * dist) - (x * x))
    @x = x + @x
    @y = @y + y
  
  
  # Point2 transforming:
  scaleBy: (scalePoint2) ->
    @multiplyBy scalePoint2
  
  translateBy: (deltaPoint2) ->
    @add deltaPoint2
  
  rotateBy: (angle, centerPoint2) ->
    center = centerPoint2 or new @constructor(0, 0)
    p = @copy().subtract(center)
    r = p.r()
    theta = angle - p.theta()
    @x = center.x + (r * Math.cos(theta))
    @y = center.y - (r * Math.sin(theta))
  
  
  # Point2 conversion:
  asArray: ->
    [@x, @y]
  
  # creating Rectangle instances from Point2:
  corner: (cornerPoint2) ->
    # answer a new Rectangle
    new Rectangle(@x, @y, cornerPoint2.x, cornerPoint2.y)
  
  rectangle: (aPoint2) ->
    # answer a new Rectangle
    org = @copy().min(aPoint2)
    crn = @copy().max(aPoint2)
    new Rectangle(org.x, org.y, crn.x, crn.y)
  
  extent: (aPoint2) ->
    #answer a new Rectangle
    crn = @copy().add(aPoint2)
    new Rectangle(@x, @y, crn.x, crn.y)
  '''

# World-wide preferences and settings ///////////////////////////////////

# Contains all possible preferences and settings for a World.
# So it's World-wide values.
# It belongs to a world, each world may have different settings.
# this comment below is needed to figure our dependencies between classes
# REQUIRES globalFunctions

class PreferencesAndSettings

  @INPUT_MODE_MOUSE: 0
  @INPUT_MODE_TOUCH: 1

  useBlurredShadows: null
  
  # all these properties can be modified
  # by the input mode.
  inputMode: null
  minimumFontHeight: null
  globalFontFamily: null
  menuFontName: null
  menuFontSize: null
  bubbleHelpFontSize: null
  prompterFontName: null
  prompterFontSize: null
  prompterSliderSize: null
  handleSize: null
  scrollBarSize: null
  mouseScrollAmount: null
  useSliderForInput: null
  useVirtualKeyboard: null
  isTouchDevice: null
  rasterizeSVGs: null
  isFlat: null

  printoutsReactiveValuesCode: true

  constructor: ->
    @useBlurredShadows = getBlurredShadowSupport() # check for Chrome-bug
    @setMouseInputMode()
    console.log("constructing PreferencesAndSettings")

  toggleBlurredShadows: ->
    @useBlurredShadows = not @useBlurredShadows

  toggleInputMode: ->
    if @inputMode == PreferencesAndSettings.INPUT_MODE_MOUSE
      @setTouchInputMode()
    else
      @setMouseInputMode()

  setMouseInputMode: ->
    @inputMode = PreferencesAndSettings.INPUT_MODE_MOUSE
    @minimumFontHeight = getMinimumFontHeight() # browser settings
    @globalFontFamily = ""
    @menuFontName = "sans-serif"
    @menuFontSize = 12
    @bubbleHelpFontSize = 10
    @prompterFontName = "sans-serif"
    @prompterFontSize = 12
    @prompterSliderSize = 10
    @handleSize = 15
    @scrollBarSize = 10
    @mouseScrollAmount = 40
    @useSliderForInput = false
    @useVirtualKeyboard = true
    @isTouchDevice = false # turned on by touch events, don't set
    @rasterizeSVGs = false
    @isFlat = false

  setTouchInputMode: ->
    @inputMode = PreferencesAndSettings.INPUT_MODE_TOUCH
    @minimumFontHeight = getMinimumFontHeight()
    @globalFontFamily = ""
    @menuFontName = "sans-serif"
    @menuFontSize = 24
    @bubbleHelpFontSize = 18
    @prompterFontName = "sans-serif"
    @prompterFontSize = 24
    @prompterSliderSize = 20
    @handleSize = 26
    @scrollBarSize = 24
    @mouseScrollAmount = 40
    @useSliderForInput = true
    @useVirtualKeyboard = true
    @isTouchDevice = false
    @rasterizeSVGs = false
    @isFlat = false


  @coffeeScriptSourceOfThisClass: '''
# World-wide preferences and settings ///////////////////////////////////

# Contains all possible preferences and settings for a World.
# So it's World-wide values.
# It belongs to a world, each world may have different settings.
# this comment below is needed to figure our dependencies between classes
# REQUIRES globalFunctions

class PreferencesAndSettings

  @INPUT_MODE_MOUSE: 0
  @INPUT_MODE_TOUCH: 1

  useBlurredShadows: null
  
  # all these properties can be modified
  # by the input mode.
  inputMode: null
  minimumFontHeight: null
  globalFontFamily: null
  menuFontName: null
  menuFontSize: null
  bubbleHelpFontSize: null
  prompterFontName: null
  prompterFontSize: null
  prompterSliderSize: null
  handleSize: null
  scrollBarSize: null
  mouseScrollAmount: null
  useSliderForInput: null
  useVirtualKeyboard: null
  isTouchDevice: null
  rasterizeSVGs: null
  isFlat: null

  printoutsReactiveValuesCode: true

  constructor: ->
    @useBlurredShadows = getBlurredShadowSupport() # check for Chrome-bug
    @setMouseInputMode()
    console.log("constructing PreferencesAndSettings")

  toggleBlurredShadows: ->
    @useBlurredShadows = not @useBlurredShadows

  toggleInputMode: ->
    if @inputMode == PreferencesAndSettings.INPUT_MODE_MOUSE
      @setTouchInputMode()
    else
      @setMouseInputMode()

  setMouseInputMode: ->
    @inputMode = PreferencesAndSettings.INPUT_MODE_MOUSE
    @minimumFontHeight = getMinimumFontHeight() # browser settings
    @globalFontFamily = ""
    @menuFontName = "sans-serif"
    @menuFontSize = 12
    @bubbleHelpFontSize = 10
    @prompterFontName = "sans-serif"
    @prompterFontSize = 12
    @prompterSliderSize = 10
    @handleSize = 15
    @scrollBarSize = 10
    @mouseScrollAmount = 40
    @useSliderForInput = false
    @useVirtualKeyboard = true
    @isTouchDevice = false # turned on by touch events, don't set
    @rasterizeSVGs = false
    @isFlat = false

  setTouchInputMode: ->
    @inputMode = PreferencesAndSettings.INPUT_MODE_TOUCH
    @minimumFontHeight = getMinimumFontHeight()
    @globalFontFamily = ""
    @menuFontName = "sans-serif"
    @menuFontSize = 24
    @bubbleHelpFontSize = 18
    @prompterFontName = "sans-serif"
    @prompterFontSize = 24
    @prompterSliderSize = 20
    @handleSize = 26
    @scrollBarSize = 24
    @mouseScrollAmount = 40
    @useSliderForInput = true
    @useVirtualKeyboard = true
    @isTouchDevice = false
    @rasterizeSVGs = false
    @isFlat = false

  '''

# Data collected at run time ///////////////////////////////////


class ProfilingDataCollector

  @shortSessionCumulativeNumberOfBrokenRects: 0
  @shortSessionMaxNumberOfBrokenRects: 0

  @shortSessionCumulativeNumberOfAllocatedCanvases: 0
  @shortSessionMaxNumberOfAllocatedCanvases: 0

  @shortSessionCumulativeSizeOfAllocatedCanvases: 0

  @shortSessionCumulativeNumberOfBlitOperations: 0
  @shortSessionMaxNumberOfBlits: 0

  @shortSessionCumulativeAreaOfBlits: 0
  @shortSessionMaxAreaOfBlits: 0

  @shortSessionBiggestBlitArea: 0

  @shortSessionCumulativeTimeSpentRedrawing: 0
  @shortSessionMaxTimeSpentRedrawing: 0
  

  @profileBrokenRects: (numberOfBrokenRects) ->
    @shortSessionCumulativeNumberOfBrokenRects += \
      numberOfBrokenRects
    if numberOfBrokenRects > \
    @shortSessionMaxNumberOfBrokenRects
      @shortSessionMaxNumberOfBrokenRects =
        numberOfBrokenRects

  @coffeeScriptSourceOfThisClass: '''
# Data collected at run time ///////////////////////////////////


class ProfilingDataCollector

  @shortSessionCumulativeNumberOfBrokenRects: 0
  @shortSessionMaxNumberOfBrokenRects: 0

  @shortSessionCumulativeNumberOfAllocatedCanvases: 0
  @shortSessionMaxNumberOfAllocatedCanvases: 0

  @shortSessionCumulativeSizeOfAllocatedCanvases: 0

  @shortSessionCumulativeNumberOfBlitOperations: 0
  @shortSessionMaxNumberOfBlits: 0

  @shortSessionCumulativeAreaOfBlits: 0
  @shortSessionMaxAreaOfBlits: 0

  @shortSessionBiggestBlitArea: 0

  @shortSessionCumulativeTimeSpentRedrawing: 0
  @shortSessionMaxTimeSpentRedrawing: 0
  

  @profileBrokenRects: (numberOfBrokenRects) ->
    @shortSessionCumulativeNumberOfBrokenRects += \
      numberOfBrokenRects
    if numberOfBrokenRects > \
    @shortSessionMaxNumberOfBrokenRects
      @shortSessionMaxNumberOfBrokenRects =
        numberOfBrokenRects
  '''

# ReactiveValuesTestsRectangleMorph /////////////////////////////////


class ReactiveValuesTestsRectangleMorph extends Morph

  count: 1
  countVal: null
  countOfDirectRectangleChildren: null

  constructor: (extent, color) ->
    super()
    @silentSetExtent(extent) if extent?
    @color = color if color?

    countValContent = {"content": @count, "signature": hashCode(@count + "")}
    @countVal = new GroundVal("countVal", countValContent, @)

    countOfDirectRectangleChildrenContent = {"content": 0, "signature": hashCode(0 + "")}

    functionToRecalculate = (argById, localArgByName, parentArgByName, childrenArgByName, childrenArgByNameCount) ->
        theCount = 0
        for allCounts of childrenArgByName["countVal"]
            theCount++

        console.log "recalculating the number of rectangles to: " + theCount

        return {
            "content": theCount,
            "signature": hashCode(theCount + "")
            }

    #constructor: (@valName, @functionToRecalculate, @localInputVals, parentArgsNames, childrenArgsNames, @ownerMorph)
    #debugger
    @countOfDirectRectangleChildren = new BasicCalculatedVal("countOfDirectRectangleChildren", functionToRecalculate, [], [], ["countVal"], @)


  @coffeeScriptSourceOfThisClass: '''
# ReactiveValuesTestsRectangleMorph /////////////////////////////////


class ReactiveValuesTestsRectangleMorph extends Morph

  count: 1
  countVal: null
  countOfDirectRectangleChildren: null

  constructor: (extent, color) ->
    super()
    @silentSetExtent(extent) if extent?
    @color = color if color?

    countValContent = {"content": @count, "signature": hashCode(@count + "")}
    @countVal = new GroundVal("countVal", countValContent, @)

    countOfDirectRectangleChildrenContent = {"content": 0, "signature": hashCode(0 + "")}

    functionToRecalculate = (argById, localArgByName, parentArgByName, childrenArgByName, childrenArgByNameCount) ->
        theCount = 0
        for allCounts of childrenArgByName["countVal"]
            theCount++

        console.log "recalculating the number of rectangles to: " + theCount

        return {
            "content": theCount,
            "signature": hashCode(theCount + "")
            }

    #constructor: (@valName, @functionToRecalculate, @localInputVals, parentArgsNames, childrenArgsNames, @ownerMorph)
    #debugger
    @countOfDirectRectangleChildren = new BasicCalculatedVal("countOfDirectRectangleChildren", functionToRecalculate, [], [], ["countVal"], @)

  '''

# A small harner to run tests around reactive values.
# To run these, just open console and type
#   ReactiveValuesTests.runTests()

# REQUIRES ReactiveValuesTestsRectangleMorph

class ReactiveValuesTests
  @runTests: ->

    # create first rectangle
    firstReactValRect = new ReactiveValuesTestsRectangleMorph()
    if ProfilerData.reactiveValues_createdGroundVals != 1
      console.log "ERROR createdGroundVals should be 1 it's " +
        ProfilerData.reactiveValues_createdGroundVals
    if ProfilerData.reactiveValues_createdBasicCalculatedValues != 1
      console.log "ERROR createdBasicCalculatedValues should be 1 it's " +
        ProfilerData.reactiveValues_createdBasicCalculatedValues
    firstReactValRect.setPosition new Point(10, 10)
    world.add firstReactValRect

    # create second rectangle, slightly displaced to verlap
    secondReactValRect = new ReactiveValuesTestsRectangleMorph()
    if ProfilerData.reactiveValues_createdGroundVals != 2
      console.log "ERROR createdGroundVals should be 2 it's " +
        ProfilerData.reactiveValues_createdGroundVals
    if ProfilerData.reactiveValues_createdBasicCalculatedValues != 2
      console.log "ERROR createdBasicCalculatedValues should be 2 it's " +
        ProfilerData.reactiveValues_createdBasicCalculatedValues
    secondReactValRect.setPosition new Point(40, 40)
    world.add secondReactValRect

    if firstReactValRect.countOfDirectRectangleChildren.lastCalculatedValContentMaybeOutdated != true
      console.log "ERROR firstReactValRect.countOfDirectRectangleChildren should be dirty and it isn't"

    # now attach the second rectangle to the first
    firstReactValRect.add secondReactValRect

    if firstReactValRect.countOfDirectRectangleChildren.lastCalculatedValContentMaybeOutdated != true
      console.log "ERROR firstReactValRect.countOfDirectRectangleChildren should be dirty and it isn't"

    # now fetch the value of countOfDirectRectangleChildren in the
    # first rectangle
    firstReactValRect.countOfDirectRectangleChildren.fetchVal()

    if firstReactValRect.countOfDirectRectangleChildren.lastCalculatedValContentMaybeOutdated != false
      console.log "ERROR firstReactValRect.countOfDirectRectangleChildren should be clean and it isn't"

    if firstReactValRect.countOfDirectRectangleChildren.lastCalculatedValContent.content != 1
      console.log "ERROR firstReactValRect.countOfDirectRectangleChildren should contain 1 and it doesn't"

    

  @coffeeScriptSourceOfThisClass: '''
# A small harner to run tests around reactive values.
# To run these, just open console and type
#   ReactiveValuesTests.runTests()

# REQUIRES ReactiveValuesTestsRectangleMorph

class ReactiveValuesTests
  @runTests: ->

    # create first rectangle
    firstReactValRect = new ReactiveValuesTestsRectangleMorph()
    if ProfilerData.reactiveValues_createdGroundVals != 1
      console.log "ERROR createdGroundVals should be 1 it's " +
        ProfilerData.reactiveValues_createdGroundVals
    if ProfilerData.reactiveValues_createdBasicCalculatedValues != 1
      console.log "ERROR createdBasicCalculatedValues should be 1 it's " +
        ProfilerData.reactiveValues_createdBasicCalculatedValues
    firstReactValRect.setPosition new Point(10, 10)
    world.add firstReactValRect

    # create second rectangle, slightly displaced to verlap
    secondReactValRect = new ReactiveValuesTestsRectangleMorph()
    if ProfilerData.reactiveValues_createdGroundVals != 2
      console.log "ERROR createdGroundVals should be 2 it's " +
        ProfilerData.reactiveValues_createdGroundVals
    if ProfilerData.reactiveValues_createdBasicCalculatedValues != 2
      console.log "ERROR createdBasicCalculatedValues should be 2 it's " +
        ProfilerData.reactiveValues_createdBasicCalculatedValues
    secondReactValRect.setPosition new Point(40, 40)
    world.add secondReactValRect

    if firstReactValRect.countOfDirectRectangleChildren.lastCalculatedValContentMaybeOutdated != true
      console.log "ERROR firstReactValRect.countOfDirectRectangleChildren should be dirty and it isn't"

    # now attach the second rectangle to the first
    firstReactValRect.add secondReactValRect

    if firstReactValRect.countOfDirectRectangleChildren.lastCalculatedValContentMaybeOutdated != true
      console.log "ERROR firstReactValRect.countOfDirectRectangleChildren should be dirty and it isn't"

    # now fetch the value of countOfDirectRectangleChildren in the
    # first rectangle
    firstReactValRect.countOfDirectRectangleChildren.fetchVal()

    if firstReactValRect.countOfDirectRectangleChildren.lastCalculatedValContentMaybeOutdated != false
      console.log "ERROR firstReactValRect.countOfDirectRectangleChildren should be clean and it isn't"

    if firstReactValRect.countOfDirectRectangleChildren.lastCalculatedValContent.content != 1
      console.log "ERROR firstReactValRect.countOfDirectRectangleChildren should contain 1 and it doesn't"

    
  '''

# ShadowMorph /////////////////////////////////////////////////////////

class ShadowMorph extends Morph
  targetMorph: null
  offset: null
  alpha: 0
  color: null

  constructor: (@targetMorph, offset, alpha, color) ->
    # console.log "creating shadow morph"
    super()
    @offset = offset or new Point(7, 7)
    @alpha = alpha or ((if (alpha is 0) then 0 else 0.2))
    @color = color or new Color(0, 0, 0)
 
  updateRendering: ->
    # console.log "shadow morph update rendering"
    fb = @targetMorph.boundsIncludingChildren()
    @silentSetExtent fb.extent().add(@targetMorph.shadowBlur * 2)
    if WorldMorph.preferencesAndSettings.useBlurredShadows and  !WorldMorph.preferencesAndSettings.isFlat
      @image = @targetMorph.shadowImageBlurred(@offset, @color)
      @setPosition fb.origin.add(@offset).subtract(@targetMorph.shadowBlur)
    else
      @image = @targetMorph.shadowImage(@offset, @color)
      @setPosition fb.origin.add(@offset)
    # console.log "shadow morph update rendering EXIT"
  
  @coffeeScriptSourceOfThisClass: '''
# ShadowMorph /////////////////////////////////////////////////////////

class ShadowMorph extends Morph
  targetMorph: null
  offset: null
  alpha: 0
  color: null

  constructor: (@targetMorph, offset, alpha, color) ->
    # console.log "creating shadow morph"
    super()
    @offset = offset or new Point(7, 7)
    @alpha = alpha or ((if (alpha is 0) then 0 else 0.2))
    @color = color or new Color(0, 0, 0)
 
  updateRendering: ->
    # console.log "shadow morph update rendering"
    fb = @targetMorph.boundsIncludingChildren()
    @silentSetExtent fb.extent().add(@targetMorph.shadowBlur * 2)
    if WorldMorph.preferencesAndSettings.useBlurredShadows and  !WorldMorph.preferencesAndSettings.isFlat
      @image = @targetMorph.shadowImageBlurred(@offset, @color)
      @setPosition fb.origin.add(@offset).subtract(@targetMorph.shadowBlur)
    else
      @image = @targetMorph.shadowImage(@offset, @color)
      @setPosition fb.origin.add(@offset)
    # console.log "shadow morph update rendering EXIT"
    '''

# SliderButtonMorph ///////////////////////////////////////////////////
# This is the handle in the middle of any slider.
# Sliders (and hence this button)
# are also used in the ScrollMorphs.

# this comment below is needed to figure our dependencies between classes
# REQUIRES globalFunctions

class SliderButtonMorph extends CircleBoxMorph

  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  highlightColor: new Color(90, 90, 140)
  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  pressColor: new Color(80, 80, 160)
  is3D: false

  constructor: (orientation) ->
    @color = new Color(80, 80, 80)
    super orientation
  
  autoOrientation: ->
      noOperation
  
  updateRendering: ->
    colorBak = @color.copy()
    super()
    @normalImage = @image
    @color = @highlightColor.copy()
    super()
    @highlightImage = @image
    @color = @pressColor.copy()
    super()
    @pressImage = @image
    @color = colorBak
    @image = @normalImage
    
  
  #SliderButtonMorph events:
  mouseEnter: ->
    @image = @highlightImage
    @changed()
  
  mouseLeave: ->
    @image = @normalImage
    @changed()
  
  mouseDownLeft: (pos) ->
    @image = @pressImage
    @changed()
    @escalateEvent "mouseDownLeft", pos
  
  mouseClickLeft: ->
    @image = @highlightImage
    @changed()
  
  # prevent my parent from getting picked up
  mouseMove: ->
      noOperation

  @coffeeScriptSourceOfThisClass: '''
# SliderButtonMorph ///////////////////////////////////////////////////
# This is the handle in the middle of any slider.
# Sliders (and hence this button)
# are also used in the ScrollMorphs.

# this comment below is needed to figure our dependencies between classes
# REQUIRES globalFunctions

class SliderButtonMorph extends CircleBoxMorph

  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  highlightColor: new Color(90, 90, 140)
  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  pressColor: new Color(80, 80, 160)
  is3D: false

  constructor: (orientation) ->
    @color = new Color(80, 80, 80)
    super orientation
  
  autoOrientation: ->
      noOperation
  
  updateRendering: ->
    colorBak = @color.copy()
    super()
    @normalImage = @image
    @color = @highlightColor.copy()
    super()
    @highlightImage = @image
    @color = @pressColor.copy()
    super()
    @pressImage = @image
    @color = colorBak
    @image = @normalImage
    
  
  #SliderButtonMorph events:
  mouseEnter: ->
    @image = @highlightImage
    @changed()
  
  mouseLeave: ->
    @image = @normalImage
    @changed()
  
  mouseDownLeft: (pos) ->
    @image = @pressImage
    @changed()
    @escalateEvent "mouseDownLeft", pos
  
  mouseClickLeft: ->
    @image = @highlightImage
    @changed()
  
  # prevent my parent from getting picked up
  mouseMove: ->
      noOperation
  '''

# SliderMorph ///////////////////////////////////////////////////
# Sliders (and hence slider button morphs)
# are also used in the ScrollMorphs .

# this comment below is needed to figure our dependencies between classes
# REQUIRES globalFunctions
# REQUIRES ControllerMixin

class SliderMorph extends CircleBoxMorph
  @augmentWith ControllerMixin

  target: null
  action: null
  start: null
  stop: null
  value: null
  size: null
  offset: null
  button: null
  step: null

  constructor: (@start = 1, @stop = 100, @value = 50, @size = 10, orientation, color) ->
    @button = new SliderButtonMorph()
    @button.isDraggable = false
    @button.color = new Color(0, 0, 0)
    @button.highlightColor = new Color(110, 110, 110)
    @button.pressColor = new Color(100, 100, 100)
    @button.alpha = 0.4
    super orientation # if null, then a vertical one will be created
    @add @button
    @alpha = 0.1
    @color = color or new Color(0, 0, 0)
    @setExtent new Point(20, 100)
  
  # this.updateRendering();
  autoOrientation: ->
      noOperation
  
  rangeSize: ->
    @stop - @start
  
  ratio: ->
    @size / @rangeSize()
  
  unitSize: ->
    if @orientation is "vertical"
      return (@height() - @button.height()) / @rangeSize()
    else
      return (@width() - @button.width()) / @rangeSize()
  
  updateRendering: ->
    super()
    @button.orientation = @orientation
    if @orientation is "vertical"
      bw = @width() - 2
      bh = Math.max(bw, Math.round(@height() * @ratio()))
      @button.silentSetExtent new Point(bw, bh)
      posX = 1
      posY = Math.min(
        Math.round((@value - @start) * @unitSize()),
        @height() - @button.height())
    else
      bh = @height() - 2
      bw = Math.max(bh, Math.round(@width() * @ratio()))
      @button.silentSetExtent new Point(bw, bh)
      posY = 1
      posX = Math.min(
        Math.round((@value - @start) * @unitSize()),
        @width() - @button.width())
    @button.setPosition new Point(posX, posY).add(@bounds.origin)
    @button.updateRendering()
    @button.changed()
  
  updateValue: ->
    if @orientation is "vertical"
      relPos = @button.top() - @top()
    else
      relPos = @button.left() - @left()
    @value = Math.round(relPos / @unitSize() + @start)
    @updateTarget()
  
  updateTarget: ->
    if @action
      if typeof @action is "function"
        @action.call @target, @value, @target
      else # assume it's a String
        @target[@action] @value
    
  
  # SliderMorph menu:
  developersMenu: ->
    menu = super()
    menu.addItem "show value", (->@showValue()), "display a dialog box\nshowing the selected number"
    menu.addItem "floor...", (->
      @prompt menu.title + "\nfloor:",
        @setStart,
        @start.toString(),
        null,
        0,
        @stop - @size,
        true
    ), "set the minimum value\nwhich can be selected"
    menu.addItem "ceiling...", (->
      @prompt menu.title + "\nceiling:",
        @setStop,
        @stop.toString(),
        null,
        @start + @size,
        @size * 100,
        true
    ), "set the maximum value\nwhich can be selected"
    menu.addItem "button size...", (->
      @prompt menu.title + "\nbutton size:",
        @setSize,
        @size.toString(),
        null,
        1,
        @stop - @start,
        true
    ), "set the range\ncovered by\nthe slider button"
    menu.addLine()
    menu.addItem "set target", (->@setTarget()), "select another morph\nwhose numerical property\nwill be " + "controlled by this one"
    menu
  
  showValue: ->
    @inform @value
  
  userSetStart: (num) ->
    # for context menu demo purposes
    @start = Math.max(num, @stop)
  
  setStart: (numOrMorphGivingNum) ->

    if numOrMorphGivingNum.getValue?
      num = numOrMorphGivingNum.getValue()
    else
      num = numOrMorphGivingNum

    # for context menu demo purposes
    if typeof num is "number"
      @start = Math.min(Math.max(num, 0), @stop - @size)
    else
      newStart = parseFloat(num)
      @start = Math.min(Math.max(newStart, 0), @stop - @size)  unless isNaN(newStart)
    @value = Math.max(@value, @start)
    @updateTarget()
    @updateRendering()
    @changed()
  
  setStop: (numOrMorphGivingNum) ->

    if numOrMorphGivingNum.getValue?
      num = numOrMorphGivingNum.getValue()
    else
      num = numOrMorphGivingNum

    # for context menu demo purposes
    if typeof num is "number"
      @stop = Math.max(num, @start + @size)
    else
      newStop = parseFloat(num)
      @stop = Math.max(newStop, @start + @size)  unless isNaN(newStop)
    @value = Math.min(@value, @stop)
    @updateTarget()
    @updateRendering()
    @changed()
  
  setSize: (sizeOrMorphGivingSize) ->
    if sizeOrMorphGivingSize.getValue?
      size = sizeOrMorphGivingSize.getValue()
    else
      size = sizeOrMorphGivingSize

    # for context menu demo purposes
    if typeof size is "number"
      @size = Math.min(Math.max(size, 1), @stop - @start)
    else
      newSize = parseFloat(size)
      @size = Math.min(Math.max(newSize, 1), @stop - @start)  unless isNaN(newSize)
    @value = Math.min(@value, @stop - @size)
    @updateTarget()
    @updateRendering()
    @changed()
  
  # setTarget: -> taken form the ControllerMixin
  
  setTargetSetter: (theTarget) ->
    choices = theTarget.numericalSetters()
    menu = new MenuMorph(@, "choose target property:")
    choices.forEach (each) =>
      menu.addItem each, =>
        @target = theTarget
        @action = each
    if choices.length == 0
      menu = new MenuMorph(@, "no target properties available")
    menu.popUpAtHand()

  
  numericalSetters: ->
    # for context menu demo purposes
    list = super()
    list.push "setStart", "setStop", "setSize"
    list
  
  
  # SliderMorph stepping:
  mouseDownLeft: (pos) ->
    unless @button.bounds.containsPoint(pos)
      @offset = new Point() # return null;
    else
      @offset = pos.subtract(@button.bounds.origin)
    world = @root()
    # this is to create the "drag the slider" effect
    # basically if the mouse is pressing within the boundaries
    # then in the next step you remember to check again where the mouse
    # is and update the scrollbar. As soon as the mouse is unpressed
    # then the step function is set to null to save cycles.
    @step = =>
      if world.hand.mouseButton and @isVisible
        mousePos = world.hand.bounds.origin
        if @orientation is "vertical"
          newX = @button.bounds.origin.x
          newY = Math.max(
            Math.min(mousePos.y - @offset.y,
            @bottom() - @button.height()), @top())
        else
          newY = @button.bounds.origin.y
          newX = Math.max(
            Math.min(mousePos.x - @offset.x,
            @right() - @button.width()), @left())
        @button.setPosition new Point(newX, newY)
        @updateValue()
      else
        @step = null

  @coffeeScriptSourceOfThisClass: '''
# SliderMorph ///////////////////////////////////////////////////
# Sliders (and hence slider button morphs)
# are also used in the ScrollMorphs .

# this comment below is needed to figure our dependencies between classes
# REQUIRES globalFunctions
# REQUIRES ControllerMixin

class SliderMorph extends CircleBoxMorph
  @augmentWith ControllerMixin

  target: null
  action: null
  start: null
  stop: null
  value: null
  size: null
  offset: null
  button: null
  step: null

  constructor: (@start = 1, @stop = 100, @value = 50, @size = 10, orientation, color) ->
    @button = new SliderButtonMorph()
    @button.isDraggable = false
    @button.color = new Color(0, 0, 0)
    @button.highlightColor = new Color(110, 110, 110)
    @button.pressColor = new Color(100, 100, 100)
    @button.alpha = 0.4
    super orientation # if null, then a vertical one will be created
    @add @button
    @alpha = 0.1
    @color = color or new Color(0, 0, 0)
    @setExtent new Point(20, 100)
  
  # this.updateRendering();
  autoOrientation: ->
      noOperation
  
  rangeSize: ->
    @stop - @start
  
  ratio: ->
    @size / @rangeSize()
  
  unitSize: ->
    if @orientation is "vertical"
      return (@height() - @button.height()) / @rangeSize()
    else
      return (@width() - @button.width()) / @rangeSize()
  
  updateRendering: ->
    super()
    @button.orientation = @orientation
    if @orientation is "vertical"
      bw = @width() - 2
      bh = Math.max(bw, Math.round(@height() * @ratio()))
      @button.silentSetExtent new Point(bw, bh)
      posX = 1
      posY = Math.min(
        Math.round((@value - @start) * @unitSize()),
        @height() - @button.height())
    else
      bh = @height() - 2
      bw = Math.max(bh, Math.round(@width() * @ratio()))
      @button.silentSetExtent new Point(bw, bh)
      posY = 1
      posX = Math.min(
        Math.round((@value - @start) * @unitSize()),
        @width() - @button.width())
    @button.setPosition new Point(posX, posY).add(@bounds.origin)
    @button.updateRendering()
    @button.changed()
  
  updateValue: ->
    if @orientation is "vertical"
      relPos = @button.top() - @top()
    else
      relPos = @button.left() - @left()
    @value = Math.round(relPos / @unitSize() + @start)
    @updateTarget()
  
  updateTarget: ->
    if @action
      if typeof @action is "function"
        @action.call @target, @value, @target
      else # assume it's a String
        @target[@action] @value
    
  
  # SliderMorph menu:
  developersMenu: ->
    menu = super()
    menu.addItem "show value", (->@showValue()), "display a dialog box\nshowing the selected number"
    menu.addItem "floor...", (->
      @prompt menu.title + "\nfloor:",
        @setStart,
        @start.toString(),
        null,
        0,
        @stop - @size,
        true
    ), "set the minimum value\nwhich can be selected"
    menu.addItem "ceiling...", (->
      @prompt menu.title + "\nceiling:",
        @setStop,
        @stop.toString(),
        null,
        @start + @size,
        @size * 100,
        true
    ), "set the maximum value\nwhich can be selected"
    menu.addItem "button size...", (->
      @prompt menu.title + "\nbutton size:",
        @setSize,
        @size.toString(),
        null,
        1,
        @stop - @start,
        true
    ), "set the range\ncovered by\nthe slider button"
    menu.addLine()
    menu.addItem "set target", (->@setTarget()), "select another morph\nwhose numerical property\nwill be " + "controlled by this one"
    menu
  
  showValue: ->
    @inform @value
  
  userSetStart: (num) ->
    # for context menu demo purposes
    @start = Math.max(num, @stop)
  
  setStart: (numOrMorphGivingNum) ->

    if numOrMorphGivingNum.getValue?
      num = numOrMorphGivingNum.getValue()
    else
      num = numOrMorphGivingNum

    # for context menu demo purposes
    if typeof num is "number"
      @start = Math.min(Math.max(num, 0), @stop - @size)
    else
      newStart = parseFloat(num)
      @start = Math.min(Math.max(newStart, 0), @stop - @size)  unless isNaN(newStart)
    @value = Math.max(@value, @start)
    @updateTarget()
    @updateRendering()
    @changed()
  
  setStop: (numOrMorphGivingNum) ->

    if numOrMorphGivingNum.getValue?
      num = numOrMorphGivingNum.getValue()
    else
      num = numOrMorphGivingNum

    # for context menu demo purposes
    if typeof num is "number"
      @stop = Math.max(num, @start + @size)
    else
      newStop = parseFloat(num)
      @stop = Math.max(newStop, @start + @size)  unless isNaN(newStop)
    @value = Math.min(@value, @stop)
    @updateTarget()
    @updateRendering()
    @changed()
  
  setSize: (sizeOrMorphGivingSize) ->
    if sizeOrMorphGivingSize.getValue?
      size = sizeOrMorphGivingSize.getValue()
    else
      size = sizeOrMorphGivingSize

    # for context menu demo purposes
    if typeof size is "number"
      @size = Math.min(Math.max(size, 1), @stop - @start)
    else
      newSize = parseFloat(size)
      @size = Math.min(Math.max(newSize, 1), @stop - @start)  unless isNaN(newSize)
    @value = Math.min(@value, @stop - @size)
    @updateTarget()
    @updateRendering()
    @changed()
  
  # setTarget: -> taken form the ControllerMixin
  
  setTargetSetter: (theTarget) ->
    choices = theTarget.numericalSetters()
    menu = new MenuMorph(@, "choose target property:")
    choices.forEach (each) =>
      menu.addItem each, =>
        @target = theTarget
        @action = each
    if choices.length == 0
      menu = new MenuMorph(@, "no target properties available")
    menu.popUpAtHand()

  
  numericalSetters: ->
    # for context menu demo purposes
    list = super()
    list.push "setStart", "setStop", "setSize"
    list
  
  
  # SliderMorph stepping:
  mouseDownLeft: (pos) ->
    unless @button.bounds.containsPoint(pos)
      @offset = new Point() # return null;
    else
      @offset = pos.subtract(@button.bounds.origin)
    world = @root()
    # this is to create the "drag the slider" effect
    # basically if the mouse is pressing within the boundaries
    # then in the next step you remember to check again where the mouse
    # is and update the scrollbar. As soon as the mouse is unpressed
    # then the step function is set to null to save cycles.
    @step = =>
      if world.hand.mouseButton and @isVisible
        mousePos = world.hand.bounds.origin
        if @orientation is "vertical"
          newX = @button.bounds.origin.x
          newY = Math.max(
            Math.min(mousePos.y - @offset.y,
            @bottom() - @button.height()), @top())
        else
          newY = @button.bounds.origin.y
          newX = Math.max(
            Math.min(mousePos.x - @offset.x,
            @right() - @button.width()), @left())
        @button.setPosition new Point(newX, newY)
        @updateValue()
      else
        @step = null
  '''

# SpeechBubbleMorph ///////////////////////////////////////////////////

#
#	I am a comic-style speech bubble that can display either a string,
#	a Morph, a Canvas or a toString() representation of anything else.
#	If I am invoked using popUp() I behave like a tool tip.
#

class SpeechBubbleMorph extends BoxMorph

  isPointingRight: true # orientation of text
  contents: null
  padding: null # additional vertical pixels
  isThought: null # draw "think" bubble
  isClickable: false
  morphInvokingThis: null

  constructor: (
    @contents="",
    @morphInvokingThis,
    color,
    edge,
    border,
    borderColor,
    @padding = 0,
    @isThought = false) ->
      # console.log "bubble super"
      @color = color or new Color(230, 230, 230)
      super edge or 6, border or ((if (border is 0) then 0 else 1)), borderColor or new Color(140, 140, 140)
      # console.log @color
  
  @createBubbleHelpIfHandStillOnMorph: (contents, morphInvokingThis) ->
    # console.log "bubble createBubbleHelpIfHandStillOnMorph"
    # let's check that the item that the
    # bubble is about is still actually there
    # and the mouse is still over it, otherwise
    # do nothing.
    if morphInvokingThis.world()? and morphInvokingThis.bounds.containsPoint(morphInvokingThis.world().hand.position())
      theBubble = new @(localize(contents), morphInvokingThis, null, null, 1)
      theBubble.popUp theBubble.morphInvokingThis.rightCenter().add(new Point(-8, 0))

  @createInAWhileIfHandStillContainedInMorph: (morphInvokingThis, contents, delay = 500) ->
    # console.log "bubble createInAWhileIfHandStillContainedInMorph"
    if SystemTestsRecorderAndPlayer.animationsPacingControl and
     SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE
        @createBubbleHelpIfHandStillOnMorph contents, morphInvokingThis
    else
      setTimeout (=>
        @createBubbleHelpIfHandStillOnMorph contents, morphInvokingThis
        )
        , delay
  
  # SpeechBubbleMorph invoking:
  popUp: (pos, isClickable) ->
    # console.log "bubble popup"
    world = @morphInvokingThis.world()
    @setPosition pos.subtract(new Point(0, @height()))
    @keepWithin world

    @buildAndConnectChildren()

    world.add @
    @addShadow new Point(2, 2), 80
    @fullChanged()
    world.hand.destroyTemporaries()
    world.hand.temporaries.push @
    if isClickable
      @mouseEnter = ->
        @destroy()
    else
      @isClickable = false
    
  buildAndConnectChildren: ->
    # console.log "bubble buildAndConnectChildren"
    # re-build my contents
    if @contentsMorph
      @contentsMorph = @contentsMorph.destroy()
    if @contents instanceof Morph
      @contentsMorph = @contents
    else if isString(@contents)
      @contentsMorph = new TextMorph(
        @contents,
        WorldMorph.preferencesAndSettings.bubbleHelpFontSize,
        null,
        false,
        true,
        "center")
    else if @contents instanceof HTMLCanvasElement
      @contentsMorph = new Morph()
      @contentsMorph.silentSetWidth @contents.width
      @contentsMorph.silentSetHeight @contents.height
      @contentsMorph.image = @contents
    else
      @contentsMorph = new TextMorph(
        @contents.toString(),
        WorldMorph.preferencesAndSettings.bubbleHelpFontSize,
        null,
        false,
        true,
        "center")
    @add @contentsMorph
    #
    # adjust my layout
    @silentSetWidth @contentsMorph.width() + ((if @padding then @padding * 2 else @edge * 2))
    @silentSetHeight @contentsMorph.height() + @edge + @border * 2 + @padding * 2 + 2
    #
    # draw my outline
    #super()
    #
    # position my contents
    @contentsMorph.setPosition @position().add(
      new Point(@padding or @edge, @border + @padding + 1))

  
  # SpeechBubbleMorph drawing:
  updateRendering: ->
    super()

  
  outlinePath: (context, radius, inset) ->
    # console.log "bubble outlinePath"
    circle = (x, y, r) ->
      context.moveTo x + r, y
      context.arc x, y, r, radians(0), radians(360)
    offset = radius + inset
    w = @width()
    h = @height()
    #
    # top left:
    context.arc offset, offset, radius, radians(-180), radians(-90), false
    #
    # top right:
    context.arc w - offset, offset, radius, radians(-90), radians(-0), false
    #
    # bottom right:
    context.arc w - offset, h - offset - radius, radius, radians(0), radians(90), false
    unless @isThought # draw speech bubble hook
      if @isPointingRight
        context.lineTo offset + radius, h - offset
        context.lineTo radius / 2 + inset, h - inset
      else # pointing left
        context.lineTo w - (radius / 2 + inset), h - inset
        context.lineTo w - (offset + radius), h - offset
    #
    # bottom left:
    context.arc offset, h - offset - radius, radius, radians(90), radians(180), false
    if @isThought
      #
      # close large bubble:
      context.lineTo inset, offset
      #
      # draw thought bubbles:
      if @isPointingRight
        #
        # tip bubble:
        rad = radius / 4
        circle rad + inset, h - rad - inset, rad
        #
        # middle bubble:
        rad = radius / 3.2
        circle rad * 2 + inset, h - rad - inset * 2, rad
        #
        # top bubble:
        rad = radius / 2.8
        circle rad * 3 + inset * 2, h - rad - inset * 4, rad
      else # pointing left
        # tip bubble:
        rad = radius / 4
        circle w - (rad + inset), h - rad - inset, rad
        #
        # middle bubble:
        rad = radius / 3.2
        circle w - (rad * 2 + inset), h - rad - inset * 2, rad
        #
        # top bubble:
        rad = radius / 2.8
        circle w - (rad * 3 + inset * 2), h - rad - inset * 4, rad

  # SpeechBubbleMorph shadow
  #
  #    only take the 'plain' image, so the box rounding and the
  #    shadow doesn't become conflicted by embedded scrolling panes
  #
  shadowImage: (off_, color) ->
    # console.log "bubble shadowImage"
    # fallback for Windows Chrome-Shadow bug
    fb = undefined
    img = undefined
    outline = undefined
    sha = undefined
    ctx = undefined
    offset = off_ or new Point(7, 7)
    clr = color or new Color(0, 0, 0)
    fb = @extent()
    img = @image
    outline = newCanvas(fb.scaleBy pixelRatio)
    ctx = outline.getContext("2d")
    #ctx.scale pixelRatio, pixelRatio
    ctx.drawImage img, 0, 0
    ctx.globalCompositeOperation = "destination-out"
    ctx.drawImage img, -offset.x * pixelRatio, -offset.y * pixelRatio
    sha = newCanvas(fb.scaleBy pixelRatio)
    ctx = sha.getContext("2d")
    #ctx.scale pixelRatio, pixelRatio
    ctx.drawImage outline, 0, 0
    ctx.globalCompositeOperation = "source-atop"
    ctx.fillStyle = clr.toString()
    ctx.fillRect 0, 0, fb.x * pixelRatio, fb.y * pixelRatio
    sha

  shadowImageBlurred: (off_, color) ->
    # console.log "bubble shadowImageBlurred"
    fb = undefined
    img = undefined
    sha = undefined
    ctx = undefined
    offset = off_ or new Point(7, 7)
    blur = @shadowBlur
    clr = color or new Color(0, 0, 0)
    fb = @extent().add(blur * 2)
    img = @image
    sha = newCanvas(fb.scaleBy pixelRatio)
    ctx = sha.getContext("2d")
    #ctx.scale pixelRatio, pixelRatio
    ctx.shadowOffsetX = offset.x * pixelRatio
    ctx.shadowOffsetY = offset.y * pixelRatio
    ctx.shadowBlur = blur * pixelRatio
    ctx.shadowColor = clr.toString()
    ctx.drawImage img, (blur - offset.x) * pixelRatio, (blur - offset.y) * pixelRatio
    ctx.shadowOffsetX = 0
    ctx.shadowOffsetY = 0
    ctx.shadowBlur = 0
    ctx.globalCompositeOperation = "destination-out"
    ctx.drawImage img, (blur - offset.x) * pixelRatio, (blur - offset.y) * pixelRatio
    sha

  # SpeechBubbleMorph resizing
  # invoked by HandleMorph
  layoutSubmorphs: ->
    # console.log "bubble layoutSubmorphs"
    #@removeShadow()
    #@updateRendering()
    #@addShadow new Point(2, 2), 80

  @coffeeScriptSourceOfThisClass: '''
# SpeechBubbleMorph ///////////////////////////////////////////////////

#
#	I am a comic-style speech bubble that can display either a string,
#	a Morph, a Canvas or a toString() representation of anything else.
#	If I am invoked using popUp() I behave like a tool tip.
#

class SpeechBubbleMorph extends BoxMorph

  isPointingRight: true # orientation of text
  contents: null
  padding: null # additional vertical pixels
  isThought: null # draw "think" bubble
  isClickable: false
  morphInvokingThis: null

  constructor: (
    @contents="",
    @morphInvokingThis,
    color,
    edge,
    border,
    borderColor,
    @padding = 0,
    @isThought = false) ->
      # console.log "bubble super"
      @color = color or new Color(230, 230, 230)
      super edge or 6, border or ((if (border is 0) then 0 else 1)), borderColor or new Color(140, 140, 140)
      # console.log @color
  
  @createBubbleHelpIfHandStillOnMorph: (contents, morphInvokingThis) ->
    # console.log "bubble createBubbleHelpIfHandStillOnMorph"
    # let's check that the item that the
    # bubble is about is still actually there
    # and the mouse is still over it, otherwise
    # do nothing.
    if morphInvokingThis.world()? and morphInvokingThis.bounds.containsPoint(morphInvokingThis.world().hand.position())
      theBubble = new @(localize(contents), morphInvokingThis, null, null, 1)
      theBubble.popUp theBubble.morphInvokingThis.rightCenter().add(new Point(-8, 0))

  @createInAWhileIfHandStillContainedInMorph: (morphInvokingThis, contents, delay = 500) ->
    # console.log "bubble createInAWhileIfHandStillContainedInMorph"
    if SystemTestsRecorderAndPlayer.animationsPacingControl and
     SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE
        @createBubbleHelpIfHandStillOnMorph contents, morphInvokingThis
    else
      setTimeout (=>
        @createBubbleHelpIfHandStillOnMorph contents, morphInvokingThis
        )
        , delay
  
  # SpeechBubbleMorph invoking:
  popUp: (pos, isClickable) ->
    # console.log "bubble popup"
    world = @morphInvokingThis.world()
    @setPosition pos.subtract(new Point(0, @height()))
    @keepWithin world

    @buildAndConnectChildren()

    world.add @
    @addShadow new Point(2, 2), 80
    @fullChanged()
    world.hand.destroyTemporaries()
    world.hand.temporaries.push @
    if isClickable
      @mouseEnter = ->
        @destroy()
    else
      @isClickable = false
    
  buildAndConnectChildren: ->
    # console.log "bubble buildAndConnectChildren"
    # re-build my contents
    if @contentsMorph
      @contentsMorph = @contentsMorph.destroy()
    if @contents instanceof Morph
      @contentsMorph = @contents
    else if isString(@contents)
      @contentsMorph = new TextMorph(
        @contents,
        WorldMorph.preferencesAndSettings.bubbleHelpFontSize,
        null,
        false,
        true,
        "center")
    else if @contents instanceof HTMLCanvasElement
      @contentsMorph = new Morph()
      @contentsMorph.silentSetWidth @contents.width
      @contentsMorph.silentSetHeight @contents.height
      @contentsMorph.image = @contents
    else
      @contentsMorph = new TextMorph(
        @contents.toString(),
        WorldMorph.preferencesAndSettings.bubbleHelpFontSize,
        null,
        false,
        true,
        "center")
    @add @contentsMorph
    #
    # adjust my layout
    @silentSetWidth @contentsMorph.width() + ((if @padding then @padding * 2 else @edge * 2))
    @silentSetHeight @contentsMorph.height() + @edge + @border * 2 + @padding * 2 + 2
    #
    # draw my outline
    #super()
    #
    # position my contents
    @contentsMorph.setPosition @position().add(
      new Point(@padding or @edge, @border + @padding + 1))

  
  # SpeechBubbleMorph drawing:
  updateRendering: ->
    super()

  
  outlinePath: (context, radius, inset) ->
    # console.log "bubble outlinePath"
    circle = (x, y, r) ->
      context.moveTo x + r, y
      context.arc x, y, r, radians(0), radians(360)
    offset = radius + inset
    w = @width()
    h = @height()
    #
    # top left:
    context.arc offset, offset, radius, radians(-180), radians(-90), false
    #
    # top right:
    context.arc w - offset, offset, radius, radians(-90), radians(-0), false
    #
    # bottom right:
    context.arc w - offset, h - offset - radius, radius, radians(0), radians(90), false
    unless @isThought # draw speech bubble hook
      if @isPointingRight
        context.lineTo offset + radius, h - offset
        context.lineTo radius / 2 + inset, h - inset
      else # pointing left
        context.lineTo w - (radius / 2 + inset), h - inset
        context.lineTo w - (offset + radius), h - offset
    #
    # bottom left:
    context.arc offset, h - offset - radius, radius, radians(90), radians(180), false
    if @isThought
      #
      # close large bubble:
      context.lineTo inset, offset
      #
      # draw thought bubbles:
      if @isPointingRight
        #
        # tip bubble:
        rad = radius / 4
        circle rad + inset, h - rad - inset, rad
        #
        # middle bubble:
        rad = radius / 3.2
        circle rad * 2 + inset, h - rad - inset * 2, rad
        #
        # top bubble:
        rad = radius / 2.8
        circle rad * 3 + inset * 2, h - rad - inset * 4, rad
      else # pointing left
        # tip bubble:
        rad = radius / 4
        circle w - (rad + inset), h - rad - inset, rad
        #
        # middle bubble:
        rad = radius / 3.2
        circle w - (rad * 2 + inset), h - rad - inset * 2, rad
        #
        # top bubble:
        rad = radius / 2.8
        circle w - (rad * 3 + inset * 2), h - rad - inset * 4, rad

  # SpeechBubbleMorph shadow
  #
  #    only take the 'plain' image, so the box rounding and the
  #    shadow doesn't become conflicted by embedded scrolling panes
  #
  shadowImage: (off_, color) ->
    # console.log "bubble shadowImage"
    # fallback for Windows Chrome-Shadow bug
    fb = undefined
    img = undefined
    outline = undefined
    sha = undefined
    ctx = undefined
    offset = off_ or new Point(7, 7)
    clr = color or new Color(0, 0, 0)
    fb = @extent()
    img = @image
    outline = newCanvas(fb.scaleBy pixelRatio)
    ctx = outline.getContext("2d")
    #ctx.scale pixelRatio, pixelRatio
    ctx.drawImage img, 0, 0
    ctx.globalCompositeOperation = "destination-out"
    ctx.drawImage img, -offset.x * pixelRatio, -offset.y * pixelRatio
    sha = newCanvas(fb.scaleBy pixelRatio)
    ctx = sha.getContext("2d")
    #ctx.scale pixelRatio, pixelRatio
    ctx.drawImage outline, 0, 0
    ctx.globalCompositeOperation = "source-atop"
    ctx.fillStyle = clr.toString()
    ctx.fillRect 0, 0, fb.x * pixelRatio, fb.y * pixelRatio
    sha

  shadowImageBlurred: (off_, color) ->
    # console.log "bubble shadowImageBlurred"
    fb = undefined
    img = undefined
    sha = undefined
    ctx = undefined
    offset = off_ or new Point(7, 7)
    blur = @shadowBlur
    clr = color or new Color(0, 0, 0)
    fb = @extent().add(blur * 2)
    img = @image
    sha = newCanvas(fb.scaleBy pixelRatio)
    ctx = sha.getContext("2d")
    #ctx.scale pixelRatio, pixelRatio
    ctx.shadowOffsetX = offset.x * pixelRatio
    ctx.shadowOffsetY = offset.y * pixelRatio
    ctx.shadowBlur = blur * pixelRatio
    ctx.shadowColor = clr.toString()
    ctx.drawImage img, (blur - offset.x) * pixelRatio, (blur - offset.y) * pixelRatio
    ctx.shadowOffsetX = 0
    ctx.shadowOffsetY = 0
    ctx.shadowBlur = 0
    ctx.globalCompositeOperation = "destination-out"
    ctx.drawImage img, (blur - offset.x) * pixelRatio, (blur - offset.y) * pixelRatio
    sha

  # SpeechBubbleMorph resizing
  # invoked by HandleMorph
  layoutSubmorphs: ->
    # console.log "bubble layoutSubmorphs"
    #@removeShadow()
    #@updateRendering()
    #@addShadow new Point(2, 2), 80
  '''

# StringFieldMorph ////////////////////////////////////////////////////

class StringFieldMorph extends FrameMorph

  defaultContents: null
  minWidth: null
  fontSize: null
  fontStyle: null
  isBold: null
  isItalic: null
  isNumeric: null
  text: null
  isEditable: true

  constructor: (
      @defaultContents = "",
      @minWidth = 100,
      @fontSize = 12,
      @fontStyle = "sans-serif",
      @isBold = false,
      @isItalic = false,
      @isNumeric = false
      ) ->
    super()
    @color = new Color(255, 255, 255)
  
  updateRendering: ->
    txt = (if @text then @getValue() else @defaultContents)
    @text = null
    @destroyAll()
    #
    @children = []
    @text = new StringMorph(txt, @fontSize, @fontStyle, @isBold, @isItalic, @isNumeric)
    @text.isNumeric = @isNumeric # for whichever reason...
    @text.setPosition @bounds.origin.copy()
    @text.isEditable = @isEditable
    @text.isDraggable = false
    @text.enableSelecting()
    @silentSetExtent new Point(Math.max(@width(), @minWidth), @text.height())
    super()
    @add @text
  
  getValue: ->
    @text.text
  
  mouseClickLeft: (pos)->
    if @isEditable
      @text.edit()
    else
      @escalateEvent 'mouseClickLeft', pos
  
  
  @coffeeScriptSourceOfThisClass: '''
# StringFieldMorph ////////////////////////////////////////////////////

class StringFieldMorph extends FrameMorph

  defaultContents: null
  minWidth: null
  fontSize: null
  fontStyle: null
  isBold: null
  isItalic: null
  isNumeric: null
  text: null
  isEditable: true

  constructor: (
      @defaultContents = "",
      @minWidth = 100,
      @fontSize = 12,
      @fontStyle = "sans-serif",
      @isBold = false,
      @isItalic = false,
      @isNumeric = false
      ) ->
    super()
    @color = new Color(255, 255, 255)
  
  updateRendering: ->
    txt = (if @text then @getValue() else @defaultContents)
    @text = null
    @destroyAll()
    #
    @children = []
    @text = new StringMorph(txt, @fontSize, @fontStyle, @isBold, @isItalic, @isNumeric)
    @text.isNumeric = @isNumeric # for whichever reason...
    @text.setPosition @bounds.origin.copy()
    @text.isEditable = @isEditable
    @text.isDraggable = false
    @text.enableSelecting()
    @silentSetExtent new Point(Math.max(@width(), @minWidth), @text.height())
    super()
    @add @text
  
  getValue: ->
    @text.text
  
  mouseClickLeft: (pos)->
    if @isEditable
      @text.edit()
    else
      @escalateEvent 'mouseClickLeft', pos
  
    '''

# WorldMorph //////////////////////////////////////////////////////////

# these comments below needed to figure our dependencies between classes
# REQUIRES globalFunctions
# REQUIRES PreferencesAndSettings
# REQUIRES Color
# REQUIRES ProfilingDataCollector

# The WorldMorph takes over the canvas on the page
class WorldMorph extends FrameMorph

  # We need to add and remove
  # the event listeners so we are
  # going to put them all in properties
  # here.
  dblclickEventListener: null
  mousedownEventListener: null
  touchstartEventListener: null
  mouseupEventListener: null
  touchendEventListener: null
  mousemoveEventListener: null
  touchmoveEventListener: null
  gesturestartEventListener: null
  gesturechangeEventListener: null
  contextmenuEventListener: null
  # Note how there can be two handlers for
  # keyboard events.
  # This one is attached
  # to the canvas and reaches the currently
  # blinking caret if there is one.
  # See below for the other potential
  # handler. See "initVirtualKeyboard"
  # method to see where and when this input and
  # these handlers are set up.
  keydownEventListener: null
  keyupEventListener: null
  keypressEventListener: null
  mousewheelEventListener: null
  DOMMouseScrollEventListener: null
  copyEventListener: null
  pasteEventListener: null

  # Note how there can be two handlers
  # for keyboard events. This one is
  # attached to a hidden
  # "input" div which keeps track of the
  # text that is being input.
  inputDOMElementForVirtualKeyboardKeydownEventListener: null
  inputDOMElementForVirtualKeyboardKeyupEventListener: null
  inputDOMElementForVirtualKeyboardKeypressEventListener: null

  keyComboResetWorldEventListener: null
  keyComboTurnOnAnimationsPacingControl: null
  keyComboTurnOffAnimationsPacingControl: null
  keyComboTakeScreenshotEventListener: null
  keyComboStopTestRecordingEventListener: null
  keyComboTakeScreenshotEventListener: null
  keyComboCheckStringsOfItemsInMenuOrderImportant: null
  keyComboCheckStringsOfItemsInMenuOrderUnimportant: null
  keyComboAddTestCommentEventListener: null
  keyComboCheckNumberOfMenuItemsEventListener: null

  dragoverEventListener: null
  dropEventListener: null
  resizeEventListener: null
  otherTasksToBeRunOnStep: []

  # these variables shouldn't be static to the WorldMorph, because
  # in pure theory you could have multiple worlds in the same
  # page with different settings
  # (but anyways, it was global before, so it's not any worse than before)
  @preferencesAndSettings: null
  @currentTime: null
  showRedraws: false
  systemTestsRecorderAndPlayer: null

  # this is the actual reference to the canvas
  # on the html page, where the world is
  # finally painted to.
  worldCanvas: null

  # By default the world will always fill
  # the entire page, also when browser window
  # is resized.
  # When this flag is set, the onResize callback
  # automatically adjusts the world size.
  automaticallyAdjustToFillEntireBrowserAlsoOnResize: true

  # keypad keys map to special characters
  # so we can trigger test actions
  # see more comments below
  @KEYPAD_TAB_mappedToThaiKeyboard_A: "ฟ"
  @KEYPAD_SLASH_mappedToThaiKeyboard_B: "ิ"
  @KEYPAD_MULTIPLY_mappedToThaiKeyboard_C: "แ"
  @KEYPAD_DELETE_mappedToThaiKeyboard_D: "ก"
  @KEYPAD_7_mappedToThaiKeyboard_E: "ำ"
  @KEYPAD_8_mappedToThaiKeyboard_F: "ด"
  @KEYPAD_9_mappedToThaiKeyboard_G: "เ"
  @KEYPAD_MINUS_mappedToThaiKeyboard_H: "้"
  @KEYPAD_4_mappedToThaiKeyboard_I: "ร"
  @KEYPAD_5_mappedToThaiKeyboard_J: "่" # looks like empty string but isn't :-)
  @KEYPAD_6_mappedToThaiKeyboard_K: "า"
  @KEYPAD_PLUS_mappedToThaiKeyboard_L: "ส" 
  @KEYPAD_1_mappedToThaiKeyboard_M: "ท"
  @KEYPAD_2_mappedToThaiKeyboard_N: "ท"
  @KEYPAD_3_mappedToThaiKeyboard_O: "ื"
  @KEYPAD_ENTER_mappedToThaiKeyboard_P: "น"
  @KEYPAD_0_mappedToThaiKeyboard_Q: "ย"
  @KEYPAD_DOT_mappedToThaiKeyboard_R: "พ"

  constructor: (
      @worldCanvas,
      @automaticallyAdjustToFillEntireBrowserAlsoOnResize = true
      ) ->

    # The WorldMorph is the very first morph to
    # be created.

    # We first need to initialise
    # some Color constants, like
    #   Color.red
    # See the comment at the beginning of the
    # color class on why this piece of code
    # is here instead of somewhere else.
    for colorName, colorValue of Color.colourNamesValues
      Color["#{colorName}"] = new Color(colorValue[0],colorValue[1], colorValue[2])
    # The colourNamesValues data structure is
    # redundant at this point.
    delete Color.colourNamesValues

    super()
    WorldMorph.preferencesAndSettings = new PreferencesAndSettings()
    console.log WorldMorph.preferencesAndSettings.menuFontName
    @color = new Color(205, 205, 205) # (130, 130, 130)
    @alpha = 1
    @isMinimised = false
    @isDraggable = false

    # additional properties:
    @stamp = Date.now() # reference in multi-world setups
    @isDevMode = false
    @broken = []
    @hand = new HandMorph(@)
    @keyboardEventsReceiver = null
    @lastEditedText = null
    @caret = null
    @activeMenu = null
    @activeHandle = null
    @inputDOMElementForVirtualKeyboard = null

    if @automaticallyAdjustToFillEntireBrowserAlsoOnResize
      @stretchWorldToFillEntirePage()

    # @worldCanvas.width and height here are in phisical pixels
    # so we want to bring them back to logical pixels
    @bounds = new Rectangle(0, 0, @worldCanvas.width / pixelRatio, @worldCanvas.height / pixelRatio)

    @initEventListeners()
    @systemTestsRecorderAndPlayer = new SystemTestsRecorderAndPlayer(@, @hand)

    @changed()
    @updateRendering()

  # see roundNumericIDsToNextThousand method in
  # Morph for an explanation of why we need this
  # method.
  alignIDsOfNextMorphsInSystemTests: ->
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE
      # Check which objects end with the word Morph
      theWordMorph = "Morph"
      listOfMorphsClasses = (Object.keys(window)).filter (i) ->
        i.indexOf(theWordMorph, i.length - theWordMorph.length) isnt -1
      for eachMorphClass in listOfMorphsClasses
        console.log "bumping up ID of class: " + eachMorphClass
        if window[eachMorphClass].roundNumericIDsToNextThousand?
          window[eachMorphClass].roundNumericIDsToNextThousand()

  
  # World Morph display:
  brokenFor: (aMorph) ->
    # private
    fb = aMorph.boundsIncludingChildren()
    @broken.filter (rect) ->
      rect.intersects fb
  
  
  # all fullDraws result into actual blittings of images done
  # by the blit function.
  # The blit function is defined in Morph and is not overriden by
  # any morph.
  recursivelyBlit: (aCanvas, aRect) ->
    # invokes the Morph's recursivelyBlit, which has only three implementations:
    #  * the default one by Morph which just invokes the blit of all children
    #  * the interesting one in FrameMorph which a) narrows the dirty
    #    rectangle (intersecting it with its border
    #    since the FrameMorph clips at its border) and b) stops recursion on all
    #    the children that are outside such intersection.
    #  * this implementation which just takes into account that the hand
    #    (which could contain a Morph being dragged)
    #    is painted on top of everything.
    super aCanvas, aRect
    # the mouse cursor is always drawn on top of everything
    # and it's not attached to the WorldMorph.
    @hand.recursivelyBlit aCanvas, aRect
  
  updateBroken: ->
    #console.log "number of broken rectangles: " + @broken.length
    ProfilingDataCollector.profileBrokenRects @broken.length

    # each broken rectangle requires traversing the scenegraph to
    # redraw what's overlapping it. Not all Morphs are traversed
    # in particular the following can stop the recursion:
    #  - invisible Morphs
    #  - FrameMorphs that don't overlap the broken rectangle
    # Since potentially there is a lot of traversal ongoin for
    # each broken rectangle, one might want to consolidate overlapping
    # and nearby rectangles.

    @broken.forEach (rect) =>
      @recursivelyBlit @worldCanvas, rect  if rect.isNotEmpty()
    @broken = []
  
  doOneCycle: ->
    WorldMorph.currentTime = Date.now();
    # console.log TextMorph.instancesCounter + " " + StringMorph.instancesCounter
    @runOtherTasksStepFunction()
    @runChildrensStepFunction()
    @updateBroken()
  
  runOtherTasksStepFunction : ->
    for task in @otherTasksToBeRunOnStep
      #console.log "running a task: " + task
      task()

  stretchWorldToFillEntirePage: ->
    pos = getDocumentPositionOf(@worldCanvas)
    clientHeight = window.innerHeight
    clientWidth = window.innerWidth
    if pos.x > 0
      @worldCanvas.style.position = "absolute"
      @worldCanvas.style.left = "0px"
      pos.x = 0
    if pos.y > 0
      @worldCanvas.style.position = "absolute"
      @worldCanvas.style.top = "0px"
      pos.y = 0
    # scrolled down b/c of viewport scaling
    clientHeight = document.documentElement.clientHeight  if document.body.scrollTop
    # scrolled left b/c of viewport scaling
    clientWidth = document.documentElement.clientWidth  if document.body.scrollLeft
    if @worldCanvas.width isnt clientWidth
      @worldCanvas.width = clientWidth
      @setWidth clientWidth
    if @worldCanvas.height isnt clientHeight
      @worldCanvas.height = clientHeight
      @setHeight clientHeight
    @children.forEach (child) =>
      child.reactToWorldResize @bounds.copy()  if child.reactToWorldResize
  
  
  
  # WorldMorph global pixel access:
  getGlobalPixelColor: (point) ->
    
    #
    #	answer the color at the given point.
    #
    #	Note: for some strange reason this method works fine if the page is
    #	opened via HTTP, but *not*, if it is opened from a local uri
    #	(e.g. from a directory), in which case it's always null.
    #
    #	This behavior is consistent throughout several browsers. I have no
    #	clue what's behind this, apparently the imageData attribute of
    #	canvas context only gets filled with meaningful data if transferred
    #	via HTTP ???
    #
    #	This is somewhat of a showstopper for color detection in a planned
    #	offline version of Snap.
    #
    #	The issue has also been discussed at: (join lines before pasting)
    #	http://stackoverflow.com/questions/4069400/
    #	canvas-getimagedata-doesnt-work-when-running-locally-on-windows-
    #	security-excep
    #
    #	The suggestion solution appears to work, since the settings are
    #	applied globally.
    #
    dta = @worldCanvas.getContext("2d").getImageData(point.x, point.y, 1, 1).data
    new Color(dta[0], dta[1], dta[2])
  
  
  # WorldMorph events:
  initVirtualKeyboard: ->
    if @inputDOMElementForVirtualKeyboard
      document.body.removeChild @inputDOMElementForVirtualKeyboard
      @inputDOMElementForVirtualKeyboard = null
    unless (WorldMorph.preferencesAndSettings.isTouchDevice and WorldMorph.preferencesAndSettings.useVirtualKeyboard)
      return
    @inputDOMElementForVirtualKeyboard = document.createElement("input")
    @inputDOMElementForVirtualKeyboard.type = "text"
    @inputDOMElementForVirtualKeyboard.style.color = "transparent"
    @inputDOMElementForVirtualKeyboard.style.backgroundColor = "transparent"
    @inputDOMElementForVirtualKeyboard.style.border = "none"
    @inputDOMElementForVirtualKeyboard.style.outline = "none"
    @inputDOMElementForVirtualKeyboard.style.position = "absolute"
    @inputDOMElementForVirtualKeyboard.style.top = "0px"
    @inputDOMElementForVirtualKeyboard.style.left = "0px"
    @inputDOMElementForVirtualKeyboard.style.width = "0px"
    @inputDOMElementForVirtualKeyboard.style.height = "0px"
    @inputDOMElementForVirtualKeyboard.autocapitalize = "none" # iOS specific
    document.body.appendChild @inputDOMElementForVirtualKeyboard

    @inputDOMElementForVirtualKeyboardKeydownEventListener = (event) =>

      @keyboardEventsReceiver.processKeyDown event  if @keyboardEventsReceiver

      # Default in several browsers
      # is for the backspace button to trigger
      # the "back button", so we prevent that
      # default here.
      if event.keyIdentifier is "U+0008" or event.keyIdentifier is "Backspace"
        event.preventDefault()  

      # suppress tab override and make sure tab gets
      # received by all browsers
      if event.keyIdentifier is "U+0009" or event.keyIdentifier is "Tab"
        @keyboardEventsReceiver.processKeyPress event  if @keyboardEventsReceiver
        event.preventDefault()

    @inputDOMElementForVirtualKeyboard.addEventListener "keydown",
      @inputDOMElementForVirtualKeyboardKeydownEventListener, false

    @inputDOMElementForVirtualKeyboardKeyupEventListener = (event) =>
      # dispatch to keyboard receiver
      if @keyboardEventsReceiver
        # so far the caret is the only keyboard
        # event handler and it has no keyup
        # handler
        if @keyboardEventsReceiver.processKeyUp
          @keyboardEventsReceiver.processKeyUp event  
      event.preventDefault()

    @inputDOMElementForVirtualKeyboard.addEventListener "keyup",
      @inputDOMElementForVirtualKeyboardKeyupEventListener, false

    @inputDOMElementForVirtualKeyboardKeypressEventListener = (event) =>
      @keyboardEventsReceiver.processKeyPress event  if @keyboardEventsReceiver
      event.preventDefault()

    @inputDOMElementForVirtualKeyboard.addEventListener "keypress",
      @inputDOMElementForVirtualKeyboardKeypressEventListener, false

  processMouseDown: (button, ctrlKey) ->
    # the recording of the test command (in case we are
    # recording a test) is handled inside the function
    # here below.
    # This is different from the other methods similar
    # to this one but there is a little bit of
    # logic we apply in case there is a right-click,
    # or user left or right-clicks on a menu,
    # in which case we record a more specific test
    # commands.

    # we might eliminate this command afterwards if
    # we find out user is clicking on a menu item
    # or right-clicking on a morph
    @systemTestsRecorderAndPlayer.addMouseDownCommand(button, ctrlKey)

    @hand.processMouseDown button, ctrlKey

  processMouseUp: (button) ->
    # event.preventDefault()

    # we might eliminate this command afterwards if
    # we find out user is clicking on a menu item
    # or right-clicking on a morph
    @systemTestsRecorderAndPlayer.addMouseUpCommand()

    @hand.processMouseUp button

  processMouseMove: (pageX, pageY) ->
    @systemTestsRecorderAndPlayer.addMouseMoveCommand(pageX, pageY)
    @hand.processMouseMove  pageX, pageY

  # event.type must be keypress
  getChar: (event) ->
    unless event.which?
      String.fromCharCode event.keyCode # IE
    else if event.which isnt 0 and event.charCode isnt 0
      String.fromCharCode event.which # the rest
    else
      null # special key

  processKeydown: (event, scanCode, shiftKey, ctrlKey, altKey, metaKey) ->
    @systemTestsRecorderAndPlayer.addKeyDownCommand scanCode, shiftKey, ctrlKey, altKey, metaKey
    if @keyboardEventsReceiver
      @keyboardEventsReceiver.processKeyDown scanCode, shiftKey, ctrlKey, altKey, metaKey

    # suppress backspace override
    if event? and scanCode is 8
      event.preventDefault()

    # suppress tab override and make sure tab gets
    # received by all browsers
    if event? and scanCode is 9
      if @keyboardEventsReceiver
        @keyboardEventsReceiver.processKeyPress scanCode, "\t", shiftKey, ctrlKey, altKey, metaKey
      event.preventDefault()

  processKeyup: (event, scanCode, shiftKey, ctrlKey, altKey, metaKey) ->
    @systemTestsRecorderAndPlayer.addKeyUpCommand scanCode, shiftKey, ctrlKey, altKey, metaKey
    # dispatch to keyboard receiver
    if @keyboardEventsReceiver
      # so far the caret is the only keyboard
      # event handler and it has no keyup
      # handler
      if @keyboardEventsReceiver.processKeyUp
        @keyboardEventsReceiver.processKeyUp scanCode, shiftKey, ctrlKey, altKey, metaKey    
    if event?
      event.preventDefault()

  processKeypress: (event, charCode, symbol, shiftKey, ctrlKey, altKey, metaKey) ->
    @systemTestsRecorderAndPlayer.addKeyPressCommand charCode, symbol, shiftKey, ctrlKey, altKey, metaKey
    # This if block adapted from:
    # http://stackoverflow.com/a/16033129
    # it rejects the
    # characters from the special
    # test-command-triggering external
    # keypad. Also there is a "00" key
    # in such keypads which is implemented
    # buy just a double-press of the zero.
    # We manage that case - if that key is
    # pressed twice we understand that it's
    # that particular key. Managing this
    # special case within Zombie Kernel
    # is not best, but there aren't any
    # good alternatives.
    if event?
      # don't manage external keypad if we are playing back
      # the tests (i.e. when event is null)
      if symbol == @constructor.KEYPAD_0_mappedToThaiKeyboard_Q
        unless @doublePressOfZeroKeypadKey?
          @doublePressOfZeroKeypadKey = 1
          setTimeout (=>
            if @doublePressOfZeroKeypadKey is 1
              console.log "single keypress"
            @doublePressOfZeroKeypadKey = null
            event.keyCode = 0
            return false
          ), 300
        else
          @doublePressOfZeroKeypadKey = null
          console.log "double keypress"
          event.keyCode = 0
        return false

    if @keyboardEventsReceiver
      @keyboardEventsReceiver.processKeyPress charCode, symbol, shiftKey, ctrlKey, altKey, metaKey
    if event?
      event.preventDefault()

  processCopy: (event) ->
    @systemTestsRecorderAndPlayer.addCopyCommand
    console.log "processing copy"
    if @caret
      selectedText = @caret.target.selection()
      if event.clipboardData
        event.preventDefault()
        setStatus = event.clipboardData.setData("text/plain", selectedText)

      if window.clipboardData
        event.returnValue = false
        setStatus = window.clipboardData.setData "Text", selectedText

  processPaste: (event, text) ->
    if @caret
      if event?
        if event.clipboardData
          # Look for access to data if types array is missing
          text = event.clipboardData.getData("text/plain")
          #url = event.clipboardData.getData("text/uri-list")
          #html = event.clipboardData.getData("text/html")
          #custom = event.clipboardData.getData("text/xcustom")
        # IE event is attached to the window object
        if window.clipboardData
          # The schema is fixed
          text = window.clipboardData.getData("Text")
          #url = window.clipboardData.getData("URL")
      
      # Needs a few msec to execute paste
      console.log "about to insert text: " + text
      @systemTestsRecorderAndPlayer.addPasteCommand text
      window.setTimeout ( => (@caret.insert text)), 50, true


  initEventListeners: ->
    canvas = @worldCanvas

    @dblclickEventListener = (event) =>
      event.preventDefault()
      @hand.processDoubleClick event
    canvas.addEventListener "dblclick", @dblclickEventListener, false

    @mousedownEventListener = (event) =>
      @processMouseDown event.button, event.ctrlKey
    canvas.addEventListener "mousedown", @mousedownEventListener, false

    @touchstartEventListener = (event) =>
      @hand.processTouchStart event
    canvas.addEventListener "touchstart", @touchstartEventListener , false
    
    @mouseupEventListener = (event) =>
      @processMouseUp event.button
    canvas.addEventListener "mouseup", @mouseupEventListener, false
    
    @touchendEventListener = (event) =>
      @hand.processTouchEnd event
    canvas.addEventListener "touchend", @touchendEventListener, false
    
    @mousemoveEventListener = (event) =>
      @processMouseMove  event.pageX, event.pageY
    canvas.addEventListener "mousemove", @mousemoveEventListener, false
    
    @touchmoveEventListener = (event) =>
      @hand.processTouchMove event
    canvas.addEventListener "touchmove", @touchmoveEventListener, false
    
    @gesturestartEventListener = (event) =>
      # Disable browser zoom
      event.preventDefault()
    canvas.addEventListener "gesturestart", @gesturestartEventListener, false
    
    @gesturechangeEventListener = (event) =>
      # Disable browser zoom
      event.preventDefault()
    canvas.addEventListener "gesturechange", @gesturechangeEventListener, false
    
    @contextmenuEventListener = (event) ->
      # suppress context menu for Mac-Firefox
      event.preventDefault()
    canvas.addEventListener "contextmenu", @contextmenuEventListener, false
    
    @keydownEventListener = (event) =>
      @processKeydown event, event.keyCode, event.shiftKey, event.ctrlKey, event.altKey, event.metaKey
    canvas.addEventListener "keydown", @keydownEventListener, false

    @keyupEventListener = (event) =>
      @processKeyup event, event.keyCode, event.shiftKey, event.ctrlKey, event.altKey, event.metaKey
    canvas.addEventListener "keyup", @keyupEventListener, false

    # This method also handles keypresses from a special
    # external keypad which is used to
    # record tests commands (such as capture screen, etc.).
    # These external keypads are inexpensive
    # so they are a good device for this kind
    # of stuff.
    # http://www.amazon.co.uk/Perixx-PERIPAD-201PLUS-Numeric-Keypad-Laptop/dp/B001R6FZLU/
    # They keypad is mapped
    # to Thai keyboard characters via an OSX app
    # called keyremap4macbook (also one needs to add the
    # Thai keyboard, which is just a click from System Preferences)
    # Those Thai characters are used to trigger test
    # commands. The only added complexity is about
    # the "00" key of such keypads - see
    # note below.
    doublePressOfZeroKeypadKey: null
    
    @keypressEventListener = (event) =>
      @processKeypress event, event.keyCode, @getChar(event), event.shiftKey, event.ctrlKey, event.altKey, event.metaKey
    canvas.addEventListener "keypress", @keypressEventListener, false

    # Safari, Chrome
    
    @mousewheelEventListener = (event) =>
      @hand.processMouseScroll event
      event.preventDefault()
    canvas.addEventListener "mousewheel", @mousewheelEventListener, false
    # Firefox
    
    @DOMMouseScrollEventListener = (event) =>
      @hand.processMouseScroll event
      event.preventDefault()
    canvas.addEventListener "DOMMouseScroll", @DOMMouseScrollEventListener, false

    # in theory there should be no scroll event on the page
    # window.addEventListener "scroll", ((event) =>
    #  nop # nothing to do, I just need this to set an interrupt point.
    # ), false

    # snippets of clipboard-handling code taken from
    # http://codebits.glennjones.net/editing/setclipboarddata.htm
    # Note that this works only in Chrome. Firefox and Safari need a piece of
    # text to be selected in order to even trigger the copy event. Chrome does
    # enable clipboard access instead even if nothing is selected.
    # There are a couple of solutions to this - one is to keep a hidden textfield that
    # handles all copy/paste operations.
    # Another one is to not use a clipboard, but rather an internal string as
    # local memory. So the OS clipboard wouldn't be used, but at least there would
    # be some copy/paste working. Also one would need to intercept the copy/paste
    # key combinations manually instead of from the copy/paste events.
    
    @copyEventListener = (event) =>
      @processCopy event
    document.body.addEventListener "copy", @copyEventListener, false

    @pasteEventListener = (event) =>
      @processPaste event
    document.body.addEventListener "paste", @pasteEventListener, false

    #console.log "binding via mousetrap"

    @keyComboResetWorldEventListener = (event) =>
      @systemTestsRecorderAndPlayer.resetWorld()
      false
    Mousetrap.bind ["alt+d"], @keyComboResetWorldEventListener

    @keyComboTurnOnAnimationsPacingControl = (event) =>
      @systemTestsRecorderAndPlayer.turnOnAnimationsPacingControl()
      false
    Mousetrap.bind ["alt+e"], @keyComboTurnOnAnimationsPacingControl

    @keyComboTurnOffAnimationsPacingControl = (event) =>
      @systemTestsRecorderAndPlayer.turnOffAnimationsPacingControl()
      false
    Mousetrap.bind ["alt+u"], @keyComboTurnOffAnimationsPacingControl

    @keyComboTakeScreenshotEventListener = (event) =>
      @systemTestsRecorderAndPlayer.takeScreenshot()
      false
    Mousetrap.bind ["alt+c"], @keyComboTakeScreenshotEventListener

    @keyComboStopTestRecordingEventListener = (event) =>
      @systemTestsRecorderAndPlayer.stopTestRecording()
      false
    Mousetrap.bind ["alt+t"], @keyComboStopTestRecordingEventListener

    @keyComboAddTestCommentEventListener = (event) =>
      @systemTestsRecorderAndPlayer.addTestComment()
      false
    Mousetrap.bind ["alt+m"], @keyComboAddTestCommentEventListener

    @keyComboCheckNumberOfMenuItemsEventListener = (event) =>
      @systemTestsRecorderAndPlayer.checkNumberOfItemsInMenu()
      false
    Mousetrap.bind ["alt+k"], @keyComboCheckNumberOfMenuItemsEventListener

    @keyComboCheckStringsOfItemsInMenuOrderImportant = (event) =>
      @systemTestsRecorderAndPlayer.checkStringsOfItemsInMenuOrderImportant()
      false
    Mousetrap.bind ["alt+a"], @keyComboCheckStringsOfItemsInMenuOrderImportant

    @keyComboCheckStringsOfItemsInMenuOrderUnimportant = (event) =>
      @systemTestsRecorderAndPlayer.checkStringsOfItemsInMenuOrderUnimportant()
      false
    Mousetrap.bind ["alt+z"], @keyComboCheckStringsOfItemsInMenuOrderUnimportant

    @dragoverEventListener = (event) ->
      event.preventDefault()
    window.addEventListener "dragover", @dragoverEventListener, false
    
    @dropEventListener = (event) =>
      @hand.processDrop event
      event.preventDefault()
    window.addEventListener "drop", @dropEventListener, false
    
    @resizeEventListener = =>
      @stretchWorldToFillEntirePage()  if @automaticallyAdjustToFillEntireBrowserAlsoOnResize
    window.addEventListener "resize", @resizeEventListener, false
    
    window.onbeforeunload = (evt) ->
      e = evt or window.event
      msg = "Are you sure you want to leave?"
      #
      # For IE and Firefox
      e.returnValue = msg  if e
      #
      # For Safari / chrome
      msg
  
  removeEventListeners: ->
    canvas = @worldCanvas
    canvas.removeEventListener 'dblclick', @dblclickEventListener
    canvas.removeEventListener 'mousedown', @mousedownEventListener
    canvas.removeEventListener 'touchstart', @touchstartEventListener
    canvas.removeEventListener 'mouseup', @mouseupEventListener
    canvas.removeEventListener 'touchend', @touchendEventListener
    canvas.removeEventListener 'mousemove', @mousemoveEventListener
    canvas.removeEventListener 'touchmove', @touchmoveEventListener
    canvas.removeEventListener 'gesturestart', @gesturestartEventListener
    canvas.removeEventListener 'gesturechange', @gesturechangeEventListener
    canvas.removeEventListener 'contextmenu', @contextmenuEventListener
    canvas.removeEventListener 'keydown', @keydownEventListener
    canvas.removeEventListener 'keyup', @keyupEventListener
    canvas.removeEventListener 'keypress', @keypressEventListener
    canvas.removeEventListener 'mousewheel', @mousewheelEventListener
    canvas.removeEventListener 'DOMMouseScroll', @DOMMouseScrollEventListener
    canvas.removeEventListener 'copy', @copyEventListener
    canvas.removeEventListener 'paste', @pasteEventListener
    Mousetrap.reset()
    canvas.removeEventListener 'dragover', @dragoverEventListener
    canvas.removeEventListener 'drop', @dropEventListener
    canvas.removeEventListener 'resize', @resizeEventListener
  
  mouseDownLeft: ->
    noOperation
  
  mouseClickLeft: ->
    noOperation
  
  mouseDownRight: ->
    noOperation
  
  mouseClickRight: ->
    noOperation
  
  wantsDropOf: ->
    # allow handle drops if any drops are allowed
    @acceptsDrops
  
  droppedImage: ->
    null

  droppedSVG: ->
    null  

  # WorldMorph text field tabbing:
  nextTab: (editField) ->
    next = @nextEntryField(editField)
    if next
      editField.clearSelection()
      next.selectAll()
      next.edit()
  
  previousTab: (editField) ->
    prev = @previousEntryField(editField)
    if prev
      editField.clearSelection()
      prev.selectAll()
      prev.edit()

  resetWorld: ->
    @destroyAll()
    # some tests might change the background
    # color of the world so let's reset it.
    @setColor(new Color(205, 205, 205))
  
  # There is something special that the
  # "world" version of destroyAll does:
  # it resets the counter used to count
  # how many morphs exist of each Morph class.
  # That counter is also used to determine the
  # unique ID of a Morph. So, destroying
  # all morphs from the world causes the
  # counts and IDs of all the subsequent
  # morphs to start from scratch again.
  destroyAll: ->
    # Check which objects end with the word Morph
    theWordMorph = "Morph"
    ListOfMorphs = (Object.keys(window)).filter (i) ->
      i.indexOf(theWordMorph, i.length - theWordMorph.length) isnt -1
    for eachMorphClass in ListOfMorphs
      if eachMorphClass != "WorldMorph"
        console.log "resetting " + eachMorphClass + " from " + window[eachMorphClass].instancesCounter
        # the actual count is in another variable "instancesCounter"
        # but all labels are built using instanceNumericID
        # which is set based on lastBuiltInstanceNumericID
        window[eachMorphClass].lastBuiltInstanceNumericID = 0

    window.world.systemTestsRecorderAndPlayer.turnOffAnimationsPacingControl()
    window.world.systemTestsRecorderAndPlayer.turnOffAlignmentOfMorphIDsMechanism()
    window.world.systemTestsRecorderAndPlayer.turnOffHidingOfMorphsGeometryInfoInLabels()
    window.world.systemTestsRecorderAndPlayer.turnOffHidingOfMorphsContentExtractInLabels()
    window.world.systemTestsRecorderAndPlayer.turnOffHidingOfMorphsNumberIDInLabels()

    super()


  # WorldMorph menu:
  unfocusMenu: (menuToBeUnfocuses) ->
    # there might be another menu
    # being spawned already has a
    # menu entry was selected so
    # let's check before setting
    # that there is no active menu
    if @activeMenu == menuToBeUnfocuses
      @activeMenu = null


  contextMenu: ->
    if @isDevMode
      menu = new MenuMorph(
        @, @constructor.name or @constructor.toString().split(" ")[1].split("(")[0])
    else
      menu = new MenuMorph(@, "Morphic")
    if @isDevMode
      menu.addItem "demo...", (->@popUpDemoMenu()), "sample morphs"
      menu.addLine()
      menu.addItem "show all", (->@showAllMinimised())
      menu.addItem "hide all", (->@minimiseAll())
      menu.addItem "delete all", (->@destroyAll())
      menu.addItem "move all inside", (->@keepAllSubmorphsWithin()), "keep all submorphs\nwithin and visible"
      menu.addItem "inspect", (->@inspect()), "open a window on\nall properties"
      menu.addLine()
      menu.addItem "restore display", (->@changed()), "redraw the\nscreen once"
      menu.addItem "fit whole page", (->@stretchWorldToFillEntirePage()), "let the World automatically\nadjust to browser resizings"
      menu.addItem "color...", (->
        @pickColor menu.title + "\ncolor:", @setColor, @color
      ), "choose the World's\nbackground color"
      if WorldMorph.preferencesAndSettings.inputMode is PreferencesAndSettings.INPUT_MODE_MOUSE
        menu.addItem "touch screen settings", (->WorldMorph.preferencesAndSettings.toggleInputMode()), "bigger menu fonts\nand sliders"
      else
        menu.addItem "standard settings", (->WorldMorph.preferencesAndSettings.toggleInputMode()), "smaller menu fonts\nand sliders"
      menu.addLine()
    
    if window.location.href.indexOf("worldWithSystemTestHarness") != -1
      menu.addItem "system tests...",  (->@popUpSystemTestsMenu()), ""
    if @isDevMode
      menu.addItem "switch to user mode", (->@toggleDevMode()), "disable developers'\ncontext menus"
    else
      menu.addItem "switch to dev mode", (->@toggleDevMode())
    menu.addItem "about Zombie Kernel...", (->@about())
    menu

  popUpSystemTestsMenu: ->
    create = (aMorph) =>
      aMorph.isDraggable = true
      aMorph.pickUp()
    menu = new MenuMorph(@, "system tests")

    menu.addItem "run system tests",  (->@systemTestsRecorderAndPlayer.runAllSystemTests()), "runs all the system tests"
    menu.addItem "start test recording",  (->@systemTestsRecorderAndPlayer.startTestRecording()), "start recording a test"
    menu.addItem "stop test recording",  (->@systemTestsRecorderAndPlayer.stopTestRecording()), "stop recording the test"
    menu.addItem "(re)play recorded test",  (->@systemTestsRecorderAndPlayer.startTestPlaying()), "start playing the test"
    menu.addItem "show test source",  (->@systemTestsRecorderAndPlayer.showTestSource()), "opens a window with the source of the latest test"
    menu.addItem "save recorded test",  (->@systemTestsRecorderAndPlayer.saveTest()), "save the recorded test"
    menu.addItem "save failed screenshots test",  (->@systemTestsRecorderAndPlayer.saveFailedScreenshots()), "save failed screenshots test"

    menu.popUpAtHand()

  popUpDemoMenu: ->
    create = (aMorph) =>
      aMorph.isDraggable = true
      aMorph.pickUp()
    menu = new MenuMorph(@, "make a morph")
    menu.addItem "rectangle", ->
      create new RectangleMorph()
    
    menu.addItem "box", ->
      create new BoxMorph()
    
    menu.addItem "circle box", ->
      create new CircleBoxMorph()
    
    menu.addLine()
    menu.addItem "slider", ->
      create new SliderMorph()
    
    menu.addItem "frame", ->
      newMorph = new FrameMorph()
      newMorph.setExtent new Point(350, 250)
      create newMorph
    
    menu.addItem "scroll frame", ->
      newMorph = new ScrollFrameMorph()
      newMorph.contents.acceptsDrops = true
      newMorph.contents.adjustBounds()
      newMorph.setExtent new Point(350, 250)
      create newMorph
    
    menu.addItem "handle", ->
      create new HandleMorph()
    
    menu.addLine()
    menu.addItem "string", ->
      newMorph = new StringMorph("Hello, World!")
      newMorph.isEditable = true
      create newMorph
    
    # this is "The Lorelei" poem (From German).
    # see translation here:
    # http://poemsintranslation.blogspot.co.uk/2009/11/heinrich-heine-lorelei-from-german.html
    menu.addItem "text", ->
      newMorph = new TextMorph("Ich weiß nicht, was soll es bedeuten, dass ich so " +
        "traurig bin, ein Märchen aus uralten Zeiten, das " +
        "kommt mir nicht aus dem Sinn. Die Luft ist kühl " +
        "und es dunkelt, und ruhig fließt der Rhein; der " +
        "Gipfel des Berges funkelt im Abendsonnenschein. " +
        "Die schönste Jungfrau sitzet dort oben wunderbar, " +
        "ihr gold'nes Geschmeide blitzet, sie kämmt ihr " +
        "goldenes Haar, sie kämmt es mit goldenem Kamme, " +
        "und singt ein Lied dabei; das hat eine wundersame, " +
        "gewalt'ge Melodei. Den Schiffer im kleinen " +
        "Schiffe, ergreift es mit wildem Weh; er schaut " +
        "nicht die Felsenriffe, er schaut nur hinauf in " +
        "die Höh'. Ich glaube, die Wellen verschlingen " +
        "am Ende Schiffer und Kahn, und das hat mit ihrem " +
        "Singen, die Loreley getan.")
      newMorph.isEditable = true
      newMorph.maxWidth = 300
      create newMorph
    
    menu.addItem "speech bubble", ->
      newMorph = new SpeechBubbleMorph("Hello, World!")
      create newMorph
    
    menu.addLine()
    menu.addItem "gray scale palette", ->
      create new GrayPaletteMorph()
    
    menu.addItem "color palette", ->
      create new ColorPaletteMorph()
    
    menu.addItem "color picker", ->
      create new ColorPickerMorph()
    
    menu.addLine()
    menu.addItem "sensor demo", ->
      newMorph = new MouseSensorMorph()
      newMorph.setColor new Color(230, 200, 100)
      newMorph.edge = 35
      newMorph.border = 15
      newMorph.borderColor = new Color(200, 100, 50)
      newMorph.alpha = 0.2
      newMorph.setExtent new Point(100, 100)
      create newMorph
    
    menu.addItem "animation demo", ->
      foo = new BouncerMorph()
      foo.setPosition new Point(50, 20)
      foo.setExtent new Point(300, 200)
      foo.alpha = 0.9
      foo.speed = 3
      bar = new BouncerMorph()
      bar.setColor new Color(50, 50, 50)
      bar.setPosition new Point(80, 80)
      bar.setExtent new Point(80, 250)
      bar.type = "horizontal"
      bar.direction = "right"
      bar.alpha = 0.9
      bar.speed = 5
      baz = new BouncerMorph()
      baz.setColor new Color(20, 20, 20)
      baz.setPosition new Point(90, 140)
      baz.setExtent new Point(40, 30)
      baz.type = "horizontal"
      baz.direction = "right"
      baz.speed = 3
      garply = new BouncerMorph()
      garply.setColor new Color(200, 20, 20)
      garply.setPosition new Point(90, 140)
      garply.setExtent new Point(20, 20)
      garply.type = "vertical"
      garply.direction = "up"
      garply.speed = 8
      fred = new BouncerMorph()
      fred.setColor new Color(20, 200, 20)
      fred.setPosition new Point(120, 140)
      fred.setExtent new Point(20, 20)
      fred.type = "vertical"
      fred.direction = "down"
      fred.speed = 4
      bar.add garply
      bar.add baz
      foo.add fred
      foo.add bar
      create foo
    
    menu.addItem "pen", ->
      create new PenMorph()
    menu.addLine()
    menu.addItem "Layout tests", (->@layoutTestsMenu()), "sample morphs"
    menu.addLine()
    menu.addItem "view all...", ->
      newMorph = new MorphsListMorph()
      create newMorph
    menu.addItem "closing window", ->
      newMorph = new WorkspaceMorph()
      create newMorph

    if @customMorphs
      menu.addLine()
      @customMorphs().forEach (morph) ->
        menu.addItem morph.toString(), ->
          create morph
    
    menu.popUpAtHand()

  layoutTestsMenu: ->
    create = (aMorph) =>
      aMorph.isDraggable = true
      aMorph.pickUp()
    menu = new MenuMorph(@, "Layout tests")
    menu.addItem "test1", ->
      LayoutMorph.test1()
    menu.addItem "test2", ->
      LayoutMorph.test2()
    menu.addItem "test3", ->
      LayoutMorph.test3()
    menu.addItem "test4", ->
      LayoutMorph.test4()
    menu.popUpAtHand()
    
  
  toggleDevMode: ->
    @isDevMode = not @isDevMode
  
  minimiseAll: ->
    @children.forEach (child) ->
      child.minimise()
  
  showAllMinimised: ->
    @forAllChildrenBottomToTop (child) ->
      child.unminimise() if child.isMinimised
  
  about: ->
    @inform "Zombie Kernel\n\n" +
      "a lively Web GUI\ninspired by Squeak\n" +
      morphicVersion +
      "\n\nby Davide Della Casa" +
      "\n\nbased on morphic.js by" +
      "\nJens Mönig (jens@moenig.org)"
  
  edit: (aStringMorphOrTextMorph) ->
    # first off, if the Morph is not editable
    # then there is nothing to do
    # return null  unless aStringMorphOrTextMorph.isEditable

    # there is only one caret in the World, so destroy
    # the previous one if there was one.
    if @caret
      # empty the previously ongoing selection
      # if there was one.
      @lastEditedText = @caret.target
      @lastEditedText.clearSelection()  if @lastEditedText
      @caret = @caret.destroy()

    # create the new Caret
    @caret = new CaretMorph(aStringMorphOrTextMorph)
    aStringMorphOrTextMorph.parent.add @caret
    # this is the only place where the @keyboardEventsReceiver is set
    @keyboardEventsReceiver = @caret

    if WorldMorph.preferencesAndSettings.isTouchDevice and WorldMorph.preferencesAndSettings.useVirtualKeyboard
      @initVirtualKeyboard()
      # For touch devices, giving focus on the textbox causes
      # the keyboard to slide up, and since the page viewport
      # shrinks, the page is scrolled to where the texbox is.
      # So, it is important to position the textbox around
      # where the caret is, so that the changed text is going to
      # be visible rather than out of the viewport.
      pos = getDocumentPositionOf(@worldCanvas)
      @inputDOMElementForVirtualKeyboard.style.top = @caret.top() + pos.y + "px"
      @inputDOMElementForVirtualKeyboard.style.left = @caret.left() + pos.x + "px"
      @inputDOMElementForVirtualKeyboard.focus()
    if WorldMorph.preferencesAndSettings.useSliderForInput
      if !aStringMorphOrTextMorph.parentThatIsA(MenuMorph)
        @slide aStringMorphOrTextMorph
  
  # Editing can stop because of three reasons:
  #   cancel (user hits ESC)
  #   accept (on stringmorph, user hits enter)
  #   user clicks/drags another morph
  stopEditing: ->
    if @caret
      @lastEditedText = @caret.target
      @lastEditedText.clearSelection()
      @lastEditedText.escalateEvent "reactToEdit", @lastEditedText
      @caret = @caret.destroy()
    # the only place where the @keyboardEventsReceiver is unset
    # (and the hidden input is removed)
    @keyboardEventsReceiver = null
    if @inputDOMElementForVirtualKeyboard
      @inputDOMElementForVirtualKeyboard.blur()
      document.body.removeChild @inputDOMElementForVirtualKeyboard
      @inputDOMElementForVirtualKeyboard = null
    @worldCanvas.focus()
  
  slide: (aStringMorphOrTextMorph) ->
    # display a slider for numeric text entries
    val = parseFloat(aStringMorphOrTextMorph.text)
    val = 0  if isNaN(val)
    menu = new MenuMorph()
    slider = new SliderMorph(val - 25, val + 25, val, 10, "horizontal")
    slider.alpha = 1
    slider.color = new Color(225, 225, 225)
    slider.button.color = menu.borderColor
    slider.button.highlightColor = slider.button.color.copy()
    slider.button.highlightColor.b += 100
    slider.button.pressColor = slider.button.color.copy()
    slider.button.pressColor.b += 150
    slider.silentSetHeight WorldMorph.preferencesAndSettings.scrollBarSize
    slider.silentSetWidth WorldMorph.preferencesAndSettings.menuFontSize * 10
    slider.updateRendering()
    slider.action = (num) ->
      aStringMorphOrTextMorph.changed()
      aStringMorphOrTextMorph.text = Math.round(num).toString()
      aStringMorphOrTextMorph.updateRendering()
      aStringMorphOrTextMorph.changed()
      aStringMorphOrTextMorph.escalateEvent(
          'reactToSliderEdit',
          aStringMorphOrTextMorph
      )
    #
    menu.items.push slider
    menu.popup @, aStringMorphOrTextMorph.bottomLeft().add(new Point(0, 5))
  
  

  @coffeeScriptSourceOfThisClass: '''
# WorldMorph //////////////////////////////////////////////////////////

# these comments below needed to figure our dependencies between classes
# REQUIRES globalFunctions
# REQUIRES PreferencesAndSettings
# REQUIRES Color
# REQUIRES ProfilingDataCollector

# The WorldMorph takes over the canvas on the page
class WorldMorph extends FrameMorph

  # We need to add and remove
  # the event listeners so we are
  # going to put them all in properties
  # here.
  dblclickEventListener: null
  mousedownEventListener: null
  touchstartEventListener: null
  mouseupEventListener: null
  touchendEventListener: null
  mousemoveEventListener: null
  touchmoveEventListener: null
  gesturestartEventListener: null
  gesturechangeEventListener: null
  contextmenuEventListener: null
  # Note how there can be two handlers for
  # keyboard events.
  # This one is attached
  # to the canvas and reaches the currently
  # blinking caret if there is one.
  # See below for the other potential
  # handler. See "initVirtualKeyboard"
  # method to see where and when this input and
  # these handlers are set up.
  keydownEventListener: null
  keyupEventListener: null
  keypressEventListener: null
  mousewheelEventListener: null
  DOMMouseScrollEventListener: null
  copyEventListener: null
  pasteEventListener: null

  # Note how there can be two handlers
  # for keyboard events. This one is
  # attached to a hidden
  # "input" div which keeps track of the
  # text that is being input.
  inputDOMElementForVirtualKeyboardKeydownEventListener: null
  inputDOMElementForVirtualKeyboardKeyupEventListener: null
  inputDOMElementForVirtualKeyboardKeypressEventListener: null

  keyComboResetWorldEventListener: null
  keyComboTurnOnAnimationsPacingControl: null
  keyComboTurnOffAnimationsPacingControl: null
  keyComboTakeScreenshotEventListener: null
  keyComboStopTestRecordingEventListener: null
  keyComboTakeScreenshotEventListener: null
  keyComboCheckStringsOfItemsInMenuOrderImportant: null
  keyComboCheckStringsOfItemsInMenuOrderUnimportant: null
  keyComboAddTestCommentEventListener: null
  keyComboCheckNumberOfMenuItemsEventListener: null

  dragoverEventListener: null
  dropEventListener: null
  resizeEventListener: null
  otherTasksToBeRunOnStep: []

  # these variables shouldn't be static to the WorldMorph, because
  # in pure theory you could have multiple worlds in the same
  # page with different settings
  # (but anyways, it was global before, so it's not any worse than before)
  @preferencesAndSettings: null
  @currentTime: null
  showRedraws: false
  systemTestsRecorderAndPlayer: null

  # this is the actual reference to the canvas
  # on the html page, where the world is
  # finally painted to.
  worldCanvas: null

  # By default the world will always fill
  # the entire page, also when browser window
  # is resized.
  # When this flag is set, the onResize callback
  # automatically adjusts the world size.
  automaticallyAdjustToFillEntireBrowserAlsoOnResize: true

  # keypad keys map to special characters
  # so we can trigger test actions
  # see more comments below
  @KEYPAD_TAB_mappedToThaiKeyboard_A: "ฟ"
  @KEYPAD_SLASH_mappedToThaiKeyboard_B: "ิ"
  @KEYPAD_MULTIPLY_mappedToThaiKeyboard_C: "แ"
  @KEYPAD_DELETE_mappedToThaiKeyboard_D: "ก"
  @KEYPAD_7_mappedToThaiKeyboard_E: "ำ"
  @KEYPAD_8_mappedToThaiKeyboard_F: "ด"
  @KEYPAD_9_mappedToThaiKeyboard_G: "เ"
  @KEYPAD_MINUS_mappedToThaiKeyboard_H: "้"
  @KEYPAD_4_mappedToThaiKeyboard_I: "ร"
  @KEYPAD_5_mappedToThaiKeyboard_J: "่" # looks like empty string but isn't :-)
  @KEYPAD_6_mappedToThaiKeyboard_K: "า"
  @KEYPAD_PLUS_mappedToThaiKeyboard_L: "ส" 
  @KEYPAD_1_mappedToThaiKeyboard_M: "ท"
  @KEYPAD_2_mappedToThaiKeyboard_N: "ท"
  @KEYPAD_3_mappedToThaiKeyboard_O: "ื"
  @KEYPAD_ENTER_mappedToThaiKeyboard_P: "น"
  @KEYPAD_0_mappedToThaiKeyboard_Q: "ย"
  @KEYPAD_DOT_mappedToThaiKeyboard_R: "พ"

  constructor: (
      @worldCanvas,
      @automaticallyAdjustToFillEntireBrowserAlsoOnResize = true
      ) ->

    # The WorldMorph is the very first morph to
    # be created.

    # We first need to initialise
    # some Color constants, like
    #   Color.red
    # See the comment at the beginning of the
    # color class on why this piece of code
    # is here instead of somewhere else.
    for colorName, colorValue of Color.colourNamesValues
      Color["#{colorName}"] = new Color(colorValue[0],colorValue[1], colorValue[2])
    # The colourNamesValues data structure is
    # redundant at this point.
    delete Color.colourNamesValues

    super()
    WorldMorph.preferencesAndSettings = new PreferencesAndSettings()
    console.log WorldMorph.preferencesAndSettings.menuFontName
    @color = new Color(205, 205, 205) # (130, 130, 130)
    @alpha = 1
    @isMinimised = false
    @isDraggable = false

    # additional properties:
    @stamp = Date.now() # reference in multi-world setups
    @isDevMode = false
    @broken = []
    @hand = new HandMorph(@)
    @keyboardEventsReceiver = null
    @lastEditedText = null
    @caret = null
    @activeMenu = null
    @activeHandle = null
    @inputDOMElementForVirtualKeyboard = null

    if @automaticallyAdjustToFillEntireBrowserAlsoOnResize
      @stretchWorldToFillEntirePage()

    # @worldCanvas.width and height here are in phisical pixels
    # so we want to bring them back to logical pixels
    @bounds = new Rectangle(0, 0, @worldCanvas.width / pixelRatio, @worldCanvas.height / pixelRatio)

    @initEventListeners()
    @systemTestsRecorderAndPlayer = new SystemTestsRecorderAndPlayer(@, @hand)

    @changed()
    @updateRendering()

  # see roundNumericIDsToNextThousand method in
  # Morph for an explanation of why we need this
  # method.
  alignIDsOfNextMorphsInSystemTests: ->
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE
      # Check which objects end with the word Morph
      theWordMorph = "Morph"
      listOfMorphsClasses = (Object.keys(window)).filter (i) ->
        i.indexOf(theWordMorph, i.length - theWordMorph.length) isnt -1
      for eachMorphClass in listOfMorphsClasses
        console.log "bumping up ID of class: " + eachMorphClass
        if window[eachMorphClass].roundNumericIDsToNextThousand?
          window[eachMorphClass].roundNumericIDsToNextThousand()

  
  # World Morph display:
  brokenFor: (aMorph) ->
    # private
    fb = aMorph.boundsIncludingChildren()
    @broken.filter (rect) ->
      rect.intersects fb
  
  
  # all fullDraws result into actual blittings of images done
  # by the blit function.
  # The blit function is defined in Morph and is not overriden by
  # any morph.
  recursivelyBlit: (aCanvas, aRect) ->
    # invokes the Morph's recursivelyBlit, which has only three implementations:
    #  * the default one by Morph which just invokes the blit of all children
    #  * the interesting one in FrameMorph which a) narrows the dirty
    #    rectangle (intersecting it with its border
    #    since the FrameMorph clips at its border) and b) stops recursion on all
    #    the children that are outside such intersection.
    #  * this implementation which just takes into account that the hand
    #    (which could contain a Morph being dragged)
    #    is painted on top of everything.
    super aCanvas, aRect
    # the mouse cursor is always drawn on top of everything
    # and it's not attached to the WorldMorph.
    @hand.recursivelyBlit aCanvas, aRect
  
  updateBroken: ->
    #console.log "number of broken rectangles: " + @broken.length
    ProfilingDataCollector.profileBrokenRects @broken.length

    # each broken rectangle requires traversing the scenegraph to
    # redraw what's overlapping it. Not all Morphs are traversed
    # in particular the following can stop the recursion:
    #  - invisible Morphs
    #  - FrameMorphs that don't overlap the broken rectangle
    # Since potentially there is a lot of traversal ongoin for
    # each broken rectangle, one might want to consolidate overlapping
    # and nearby rectangles.

    @broken.forEach (rect) =>
      @recursivelyBlit @worldCanvas, rect  if rect.isNotEmpty()
    @broken = []
  
  doOneCycle: ->
    WorldMorph.currentTime = Date.now();
    # console.log TextMorph.instancesCounter + " " + StringMorph.instancesCounter
    @runOtherTasksStepFunction()
    @runChildrensStepFunction()
    @updateBroken()
  
  runOtherTasksStepFunction : ->
    for task in @otherTasksToBeRunOnStep
      #console.log "running a task: " + task
      task()

  stretchWorldToFillEntirePage: ->
    pos = getDocumentPositionOf(@worldCanvas)
    clientHeight = window.innerHeight
    clientWidth = window.innerWidth
    if pos.x > 0
      @worldCanvas.style.position = "absolute"
      @worldCanvas.style.left = "0px"
      pos.x = 0
    if pos.y > 0
      @worldCanvas.style.position = "absolute"
      @worldCanvas.style.top = "0px"
      pos.y = 0
    # scrolled down b/c of viewport scaling
    clientHeight = document.documentElement.clientHeight  if document.body.scrollTop
    # scrolled left b/c of viewport scaling
    clientWidth = document.documentElement.clientWidth  if document.body.scrollLeft
    if @worldCanvas.width isnt clientWidth
      @worldCanvas.width = clientWidth
      @setWidth clientWidth
    if @worldCanvas.height isnt clientHeight
      @worldCanvas.height = clientHeight
      @setHeight clientHeight
    @children.forEach (child) =>
      child.reactToWorldResize @bounds.copy()  if child.reactToWorldResize
  
  
  
  # WorldMorph global pixel access:
  getGlobalPixelColor: (point) ->
    
    #
    #	answer the color at the given point.
    #
    #	Note: for some strange reason this method works fine if the page is
    #	opened via HTTP, but *not*, if it is opened from a local uri
    #	(e.g. from a directory), in which case it's always null.
    #
    #	This behavior is consistent throughout several browsers. I have no
    #	clue what's behind this, apparently the imageData attribute of
    #	canvas context only gets filled with meaningful data if transferred
    #	via HTTP ???
    #
    #	This is somewhat of a showstopper for color detection in a planned
    #	offline version of Snap.
    #
    #	The issue has also been discussed at: (join lines before pasting)
    #	http://stackoverflow.com/questions/4069400/
    #	canvas-getimagedata-doesnt-work-when-running-locally-on-windows-
    #	security-excep
    #
    #	The suggestion solution appears to work, since the settings are
    #	applied globally.
    #
    dta = @worldCanvas.getContext("2d").getImageData(point.x, point.y, 1, 1).data
    new Color(dta[0], dta[1], dta[2])
  
  
  # WorldMorph events:
  initVirtualKeyboard: ->
    if @inputDOMElementForVirtualKeyboard
      document.body.removeChild @inputDOMElementForVirtualKeyboard
      @inputDOMElementForVirtualKeyboard = null
    unless (WorldMorph.preferencesAndSettings.isTouchDevice and WorldMorph.preferencesAndSettings.useVirtualKeyboard)
      return
    @inputDOMElementForVirtualKeyboard = document.createElement("input")
    @inputDOMElementForVirtualKeyboard.type = "text"
    @inputDOMElementForVirtualKeyboard.style.color = "transparent"
    @inputDOMElementForVirtualKeyboard.style.backgroundColor = "transparent"
    @inputDOMElementForVirtualKeyboard.style.border = "none"
    @inputDOMElementForVirtualKeyboard.style.outline = "none"
    @inputDOMElementForVirtualKeyboard.style.position = "absolute"
    @inputDOMElementForVirtualKeyboard.style.top = "0px"
    @inputDOMElementForVirtualKeyboard.style.left = "0px"
    @inputDOMElementForVirtualKeyboard.style.width = "0px"
    @inputDOMElementForVirtualKeyboard.style.height = "0px"
    @inputDOMElementForVirtualKeyboard.autocapitalize = "none" # iOS specific
    document.body.appendChild @inputDOMElementForVirtualKeyboard

    @inputDOMElementForVirtualKeyboardKeydownEventListener = (event) =>

      @keyboardEventsReceiver.processKeyDown event  if @keyboardEventsReceiver

      # Default in several browsers
      # is for the backspace button to trigger
      # the "back button", so we prevent that
      # default here.
      if event.keyIdentifier is "U+0008" or event.keyIdentifier is "Backspace"
        event.preventDefault()  

      # suppress tab override and make sure tab gets
      # received by all browsers
      if event.keyIdentifier is "U+0009" or event.keyIdentifier is "Tab"
        @keyboardEventsReceiver.processKeyPress event  if @keyboardEventsReceiver
        event.preventDefault()

    @inputDOMElementForVirtualKeyboard.addEventListener "keydown",
      @inputDOMElementForVirtualKeyboardKeydownEventListener, false

    @inputDOMElementForVirtualKeyboardKeyupEventListener = (event) =>
      # dispatch to keyboard receiver
      if @keyboardEventsReceiver
        # so far the caret is the only keyboard
        # event handler and it has no keyup
        # handler
        if @keyboardEventsReceiver.processKeyUp
          @keyboardEventsReceiver.processKeyUp event  
      event.preventDefault()

    @inputDOMElementForVirtualKeyboard.addEventListener "keyup",
      @inputDOMElementForVirtualKeyboardKeyupEventListener, false

    @inputDOMElementForVirtualKeyboardKeypressEventListener = (event) =>
      @keyboardEventsReceiver.processKeyPress event  if @keyboardEventsReceiver
      event.preventDefault()

    @inputDOMElementForVirtualKeyboard.addEventListener "keypress",
      @inputDOMElementForVirtualKeyboardKeypressEventListener, false

  processMouseDown: (button, ctrlKey) ->
    # the recording of the test command (in case we are
    # recording a test) is handled inside the function
    # here below.
    # This is different from the other methods similar
    # to this one but there is a little bit of
    # logic we apply in case there is a right-click,
    # or user left or right-clicks on a menu,
    # in which case we record a more specific test
    # commands.

    # we might eliminate this command afterwards if
    # we find out user is clicking on a menu item
    # or right-clicking on a morph
    @systemTestsRecorderAndPlayer.addMouseDownCommand(button, ctrlKey)

    @hand.processMouseDown button, ctrlKey

  processMouseUp: (button) ->
    # event.preventDefault()

    # we might eliminate this command afterwards if
    # we find out user is clicking on a menu item
    # or right-clicking on a morph
    @systemTestsRecorderAndPlayer.addMouseUpCommand()

    @hand.processMouseUp button

  processMouseMove: (pageX, pageY) ->
    @systemTestsRecorderAndPlayer.addMouseMoveCommand(pageX, pageY)
    @hand.processMouseMove  pageX, pageY

  # event.type must be keypress
  getChar: (event) ->
    unless event.which?
      String.fromCharCode event.keyCode # IE
    else if event.which isnt 0 and event.charCode isnt 0
      String.fromCharCode event.which # the rest
    else
      null # special key

  processKeydown: (event, scanCode, shiftKey, ctrlKey, altKey, metaKey) ->
    @systemTestsRecorderAndPlayer.addKeyDownCommand scanCode, shiftKey, ctrlKey, altKey, metaKey
    if @keyboardEventsReceiver
      @keyboardEventsReceiver.processKeyDown scanCode, shiftKey, ctrlKey, altKey, metaKey

    # suppress backspace override
    if event? and scanCode is 8
      event.preventDefault()

    # suppress tab override and make sure tab gets
    # received by all browsers
    if event? and scanCode is 9
      if @keyboardEventsReceiver
        @keyboardEventsReceiver.processKeyPress scanCode, "\t", shiftKey, ctrlKey, altKey, metaKey
      event.preventDefault()

  processKeyup: (event, scanCode, shiftKey, ctrlKey, altKey, metaKey) ->
    @systemTestsRecorderAndPlayer.addKeyUpCommand scanCode, shiftKey, ctrlKey, altKey, metaKey
    # dispatch to keyboard receiver
    if @keyboardEventsReceiver
      # so far the caret is the only keyboard
      # event handler and it has no keyup
      # handler
      if @keyboardEventsReceiver.processKeyUp
        @keyboardEventsReceiver.processKeyUp scanCode, shiftKey, ctrlKey, altKey, metaKey    
    if event?
      event.preventDefault()

  processKeypress: (event, charCode, symbol, shiftKey, ctrlKey, altKey, metaKey) ->
    @systemTestsRecorderAndPlayer.addKeyPressCommand charCode, symbol, shiftKey, ctrlKey, altKey, metaKey
    # This if block adapted from:
    # http://stackoverflow.com/a/16033129
    # it rejects the
    # characters from the special
    # test-command-triggering external
    # keypad. Also there is a "00" key
    # in such keypads which is implemented
    # buy just a double-press of the zero.
    # We manage that case - if that key is
    # pressed twice we understand that it's
    # that particular key. Managing this
    # special case within Zombie Kernel
    # is not best, but there aren't any
    # good alternatives.
    if event?
      # don't manage external keypad if we are playing back
      # the tests (i.e. when event is null)
      if symbol == @constructor.KEYPAD_0_mappedToThaiKeyboard_Q
        unless @doublePressOfZeroKeypadKey?
          @doublePressOfZeroKeypadKey = 1
          setTimeout (=>
            if @doublePressOfZeroKeypadKey is 1
              console.log "single keypress"
            @doublePressOfZeroKeypadKey = null
            event.keyCode = 0
            return false
          ), 300
        else
          @doublePressOfZeroKeypadKey = null
          console.log "double keypress"
          event.keyCode = 0
        return false

    if @keyboardEventsReceiver
      @keyboardEventsReceiver.processKeyPress charCode, symbol, shiftKey, ctrlKey, altKey, metaKey
    if event?
      event.preventDefault()

  processCopy: (event) ->
    @systemTestsRecorderAndPlayer.addCopyCommand
    console.log "processing copy"
    if @caret
      selectedText = @caret.target.selection()
      if event.clipboardData
        event.preventDefault()
        setStatus = event.clipboardData.setData("text/plain", selectedText)

      if window.clipboardData
        event.returnValue = false
        setStatus = window.clipboardData.setData "Text", selectedText

  processPaste: (event, text) ->
    if @caret
      if event?
        if event.clipboardData
          # Look for access to data if types array is missing
          text = event.clipboardData.getData("text/plain")
          #url = event.clipboardData.getData("text/uri-list")
          #html = event.clipboardData.getData("text/html")
          #custom = event.clipboardData.getData("text/xcustom")
        # IE event is attached to the window object
        if window.clipboardData
          # The schema is fixed
          text = window.clipboardData.getData("Text")
          #url = window.clipboardData.getData("URL")
      
      # Needs a few msec to execute paste
      console.log "about to insert text: " + text
      @systemTestsRecorderAndPlayer.addPasteCommand text
      window.setTimeout ( => (@caret.insert text)), 50, true


  initEventListeners: ->
    canvas = @worldCanvas

    @dblclickEventListener = (event) =>
      event.preventDefault()
      @hand.processDoubleClick event
    canvas.addEventListener "dblclick", @dblclickEventListener, false

    @mousedownEventListener = (event) =>
      @processMouseDown event.button, event.ctrlKey
    canvas.addEventListener "mousedown", @mousedownEventListener, false

    @touchstartEventListener = (event) =>
      @hand.processTouchStart event
    canvas.addEventListener "touchstart", @touchstartEventListener , false
    
    @mouseupEventListener = (event) =>
      @processMouseUp event.button
    canvas.addEventListener "mouseup", @mouseupEventListener, false
    
    @touchendEventListener = (event) =>
      @hand.processTouchEnd event
    canvas.addEventListener "touchend", @touchendEventListener, false
    
    @mousemoveEventListener = (event) =>
      @processMouseMove  event.pageX, event.pageY
    canvas.addEventListener "mousemove", @mousemoveEventListener, false
    
    @touchmoveEventListener = (event) =>
      @hand.processTouchMove event
    canvas.addEventListener "touchmove", @touchmoveEventListener, false
    
    @gesturestartEventListener = (event) =>
      # Disable browser zoom
      event.preventDefault()
    canvas.addEventListener "gesturestart", @gesturestartEventListener, false
    
    @gesturechangeEventListener = (event) =>
      # Disable browser zoom
      event.preventDefault()
    canvas.addEventListener "gesturechange", @gesturechangeEventListener, false
    
    @contextmenuEventListener = (event) ->
      # suppress context menu for Mac-Firefox
      event.preventDefault()
    canvas.addEventListener "contextmenu", @contextmenuEventListener, false
    
    @keydownEventListener = (event) =>
      @processKeydown event, event.keyCode, event.shiftKey, event.ctrlKey, event.altKey, event.metaKey
    canvas.addEventListener "keydown", @keydownEventListener, false

    @keyupEventListener = (event) =>
      @processKeyup event, event.keyCode, event.shiftKey, event.ctrlKey, event.altKey, event.metaKey
    canvas.addEventListener "keyup", @keyupEventListener, false

    # This method also handles keypresses from a special
    # external keypad which is used to
    # record tests commands (such as capture screen, etc.).
    # These external keypads are inexpensive
    # so they are a good device for this kind
    # of stuff.
    # http://www.amazon.co.uk/Perixx-PERIPAD-201PLUS-Numeric-Keypad-Laptop/dp/B001R6FZLU/
    # They keypad is mapped
    # to Thai keyboard characters via an OSX app
    # called keyremap4macbook (also one needs to add the
    # Thai keyboard, which is just a click from System Preferences)
    # Those Thai characters are used to trigger test
    # commands. The only added complexity is about
    # the "00" key of such keypads - see
    # note below.
    doublePressOfZeroKeypadKey: null
    
    @keypressEventListener = (event) =>
      @processKeypress event, event.keyCode, @getChar(event), event.shiftKey, event.ctrlKey, event.altKey, event.metaKey
    canvas.addEventListener "keypress", @keypressEventListener, false

    # Safari, Chrome
    
    @mousewheelEventListener = (event) =>
      @hand.processMouseScroll event
      event.preventDefault()
    canvas.addEventListener "mousewheel", @mousewheelEventListener, false
    # Firefox
    
    @DOMMouseScrollEventListener = (event) =>
      @hand.processMouseScroll event
      event.preventDefault()
    canvas.addEventListener "DOMMouseScroll", @DOMMouseScrollEventListener, false

    # in theory there should be no scroll event on the page
    # window.addEventListener "scroll", ((event) =>
    #  nop # nothing to do, I just need this to set an interrupt point.
    # ), false

    # snippets of clipboard-handling code taken from
    # http://codebits.glennjones.net/editing/setclipboarddata.htm
    # Note that this works only in Chrome. Firefox and Safari need a piece of
    # text to be selected in order to even trigger the copy event. Chrome does
    # enable clipboard access instead even if nothing is selected.
    # There are a couple of solutions to this - one is to keep a hidden textfield that
    # handles all copy/paste operations.
    # Another one is to not use a clipboard, but rather an internal string as
    # local memory. So the OS clipboard wouldn't be used, but at least there would
    # be some copy/paste working. Also one would need to intercept the copy/paste
    # key combinations manually instead of from the copy/paste events.
    
    @copyEventListener = (event) =>
      @processCopy event
    document.body.addEventListener "copy", @copyEventListener, false

    @pasteEventListener = (event) =>
      @processPaste event
    document.body.addEventListener "paste", @pasteEventListener, false

    #console.log "binding via mousetrap"

    @keyComboResetWorldEventListener = (event) =>
      @systemTestsRecorderAndPlayer.resetWorld()
      false
    Mousetrap.bind ["alt+d"], @keyComboResetWorldEventListener

    @keyComboTurnOnAnimationsPacingControl = (event) =>
      @systemTestsRecorderAndPlayer.turnOnAnimationsPacingControl()
      false
    Mousetrap.bind ["alt+e"], @keyComboTurnOnAnimationsPacingControl

    @keyComboTurnOffAnimationsPacingControl = (event) =>
      @systemTestsRecorderAndPlayer.turnOffAnimationsPacingControl()
      false
    Mousetrap.bind ["alt+u"], @keyComboTurnOffAnimationsPacingControl

    @keyComboTakeScreenshotEventListener = (event) =>
      @systemTestsRecorderAndPlayer.takeScreenshot()
      false
    Mousetrap.bind ["alt+c"], @keyComboTakeScreenshotEventListener

    @keyComboStopTestRecordingEventListener = (event) =>
      @systemTestsRecorderAndPlayer.stopTestRecording()
      false
    Mousetrap.bind ["alt+t"], @keyComboStopTestRecordingEventListener

    @keyComboAddTestCommentEventListener = (event) =>
      @systemTestsRecorderAndPlayer.addTestComment()
      false
    Mousetrap.bind ["alt+m"], @keyComboAddTestCommentEventListener

    @keyComboCheckNumberOfMenuItemsEventListener = (event) =>
      @systemTestsRecorderAndPlayer.checkNumberOfItemsInMenu()
      false
    Mousetrap.bind ["alt+k"], @keyComboCheckNumberOfMenuItemsEventListener

    @keyComboCheckStringsOfItemsInMenuOrderImportant = (event) =>
      @systemTestsRecorderAndPlayer.checkStringsOfItemsInMenuOrderImportant()
      false
    Mousetrap.bind ["alt+a"], @keyComboCheckStringsOfItemsInMenuOrderImportant

    @keyComboCheckStringsOfItemsInMenuOrderUnimportant = (event) =>
      @systemTestsRecorderAndPlayer.checkStringsOfItemsInMenuOrderUnimportant()
      false
    Mousetrap.bind ["alt+z"], @keyComboCheckStringsOfItemsInMenuOrderUnimportant

    @dragoverEventListener = (event) ->
      event.preventDefault()
    window.addEventListener "dragover", @dragoverEventListener, false
    
    @dropEventListener = (event) =>
      @hand.processDrop event
      event.preventDefault()
    window.addEventListener "drop", @dropEventListener, false
    
    @resizeEventListener = =>
      @stretchWorldToFillEntirePage()  if @automaticallyAdjustToFillEntireBrowserAlsoOnResize
    window.addEventListener "resize", @resizeEventListener, false
    
    window.onbeforeunload = (evt) ->
      e = evt or window.event
      msg = "Are you sure you want to leave?"
      #
      # For IE and Firefox
      e.returnValue = msg  if e
      #
      # For Safari / chrome
      msg
  
  removeEventListeners: ->
    canvas = @worldCanvas
    canvas.removeEventListener 'dblclick', @dblclickEventListener
    canvas.removeEventListener 'mousedown', @mousedownEventListener
    canvas.removeEventListener 'touchstart', @touchstartEventListener
    canvas.removeEventListener 'mouseup', @mouseupEventListener
    canvas.removeEventListener 'touchend', @touchendEventListener
    canvas.removeEventListener 'mousemove', @mousemoveEventListener
    canvas.removeEventListener 'touchmove', @touchmoveEventListener
    canvas.removeEventListener 'gesturestart', @gesturestartEventListener
    canvas.removeEventListener 'gesturechange', @gesturechangeEventListener
    canvas.removeEventListener 'contextmenu', @contextmenuEventListener
    canvas.removeEventListener 'keydown', @keydownEventListener
    canvas.removeEventListener 'keyup', @keyupEventListener
    canvas.removeEventListener 'keypress', @keypressEventListener
    canvas.removeEventListener 'mousewheel', @mousewheelEventListener
    canvas.removeEventListener 'DOMMouseScroll', @DOMMouseScrollEventListener
    canvas.removeEventListener 'copy', @copyEventListener
    canvas.removeEventListener 'paste', @pasteEventListener
    Mousetrap.reset()
    canvas.removeEventListener 'dragover', @dragoverEventListener
    canvas.removeEventListener 'drop', @dropEventListener
    canvas.removeEventListener 'resize', @resizeEventListener
  
  mouseDownLeft: ->
    noOperation
  
  mouseClickLeft: ->
    noOperation
  
  mouseDownRight: ->
    noOperation
  
  mouseClickRight: ->
    noOperation
  
  wantsDropOf: ->
    # allow handle drops if any drops are allowed
    @acceptsDrops
  
  droppedImage: ->
    null

  droppedSVG: ->
    null  

  # WorldMorph text field tabbing:
  nextTab: (editField) ->
    next = @nextEntryField(editField)
    if next
      editField.clearSelection()
      next.selectAll()
      next.edit()
  
  previousTab: (editField) ->
    prev = @previousEntryField(editField)
    if prev
      editField.clearSelection()
      prev.selectAll()
      prev.edit()

  resetWorld: ->
    @destroyAll()
    # some tests might change the background
    # color of the world so let's reset it.
    @setColor(new Color(205, 205, 205))
  
  # There is something special that the
  # "world" version of destroyAll does:
  # it resets the counter used to count
  # how many morphs exist of each Morph class.
  # That counter is also used to determine the
  # unique ID of a Morph. So, destroying
  # all morphs from the world causes the
  # counts and IDs of all the subsequent
  # morphs to start from scratch again.
  destroyAll: ->
    # Check which objects end with the word Morph
    theWordMorph = "Morph"
    ListOfMorphs = (Object.keys(window)).filter (i) ->
      i.indexOf(theWordMorph, i.length - theWordMorph.length) isnt -1
    for eachMorphClass in ListOfMorphs
      if eachMorphClass != "WorldMorph"
        console.log "resetting " + eachMorphClass + " from " + window[eachMorphClass].instancesCounter
        # the actual count is in another variable "instancesCounter"
        # but all labels are built using instanceNumericID
        # which is set based on lastBuiltInstanceNumericID
        window[eachMorphClass].lastBuiltInstanceNumericID = 0

    window.world.systemTestsRecorderAndPlayer.turnOffAnimationsPacingControl()
    window.world.systemTestsRecorderAndPlayer.turnOffAlignmentOfMorphIDsMechanism()
    window.world.systemTestsRecorderAndPlayer.turnOffHidingOfMorphsGeometryInfoInLabels()
    window.world.systemTestsRecorderAndPlayer.turnOffHidingOfMorphsContentExtractInLabels()
    window.world.systemTestsRecorderAndPlayer.turnOffHidingOfMorphsNumberIDInLabels()

    super()


  # WorldMorph menu:
  unfocusMenu: (menuToBeUnfocuses) ->
    # there might be another menu
    # being spawned already has a
    # menu entry was selected so
    # let's check before setting
    # that there is no active menu
    if @activeMenu == menuToBeUnfocuses
      @activeMenu = null


  contextMenu: ->
    if @isDevMode
      menu = new MenuMorph(
        @, @constructor.name or @constructor.toString().split(" ")[1].split("(")[0])
    else
      menu = new MenuMorph(@, "Morphic")
    if @isDevMode
      menu.addItem "demo...", (->@popUpDemoMenu()), "sample morphs"
      menu.addLine()
      menu.addItem "show all", (->@showAllMinimised())
      menu.addItem "hide all", (->@minimiseAll())
      menu.addItem "delete all", (->@destroyAll())
      menu.addItem "move all inside", (->@keepAllSubmorphsWithin()), "keep all submorphs\nwithin and visible"
      menu.addItem "inspect", (->@inspect()), "open a window on\nall properties"
      menu.addLine()
      menu.addItem "restore display", (->@changed()), "redraw the\nscreen once"
      menu.addItem "fit whole page", (->@stretchWorldToFillEntirePage()), "let the World automatically\nadjust to browser resizings"
      menu.addItem "color...", (->
        @pickColor menu.title + "\ncolor:", @setColor, @color
      ), "choose the World's\nbackground color"
      if WorldMorph.preferencesAndSettings.inputMode is PreferencesAndSettings.INPUT_MODE_MOUSE
        menu.addItem "touch screen settings", (->WorldMorph.preferencesAndSettings.toggleInputMode()), "bigger menu fonts\nand sliders"
      else
        menu.addItem "standard settings", (->WorldMorph.preferencesAndSettings.toggleInputMode()), "smaller menu fonts\nand sliders"
      menu.addLine()
    
    if window.location.href.indexOf("worldWithSystemTestHarness") != -1
      menu.addItem "system tests...",  (->@popUpSystemTestsMenu()), ""
    if @isDevMode
      menu.addItem "switch to user mode", (->@toggleDevMode()), "disable developers'\ncontext menus"
    else
      menu.addItem "switch to dev mode", (->@toggleDevMode())
    menu.addItem "about Zombie Kernel...", (->@about())
    menu

  popUpSystemTestsMenu: ->
    create = (aMorph) =>
      aMorph.isDraggable = true
      aMorph.pickUp()
    menu = new MenuMorph(@, "system tests")

    menu.addItem "run system tests",  (->@systemTestsRecorderAndPlayer.runAllSystemTests()), "runs all the system tests"
    menu.addItem "start test recording",  (->@systemTestsRecorderAndPlayer.startTestRecording()), "start recording a test"
    menu.addItem "stop test recording",  (->@systemTestsRecorderAndPlayer.stopTestRecording()), "stop recording the test"
    menu.addItem "(re)play recorded test",  (->@systemTestsRecorderAndPlayer.startTestPlaying()), "start playing the test"
    menu.addItem "show test source",  (->@systemTestsRecorderAndPlayer.showTestSource()), "opens a window with the source of the latest test"
    menu.addItem "save recorded test",  (->@systemTestsRecorderAndPlayer.saveTest()), "save the recorded test"
    menu.addItem "save failed screenshots test",  (->@systemTestsRecorderAndPlayer.saveFailedScreenshots()), "save failed screenshots test"

    menu.popUpAtHand()

  popUpDemoMenu: ->
    create = (aMorph) =>
      aMorph.isDraggable = true
      aMorph.pickUp()
    menu = new MenuMorph(@, "make a morph")
    menu.addItem "rectangle", ->
      create new RectangleMorph()
    
    menu.addItem "box", ->
      create new BoxMorph()
    
    menu.addItem "circle box", ->
      create new CircleBoxMorph()
    
    menu.addLine()
    menu.addItem "slider", ->
      create new SliderMorph()
    
    menu.addItem "frame", ->
      newMorph = new FrameMorph()
      newMorph.setExtent new Point(350, 250)
      create newMorph
    
    menu.addItem "scroll frame", ->
      newMorph = new ScrollFrameMorph()
      newMorph.contents.acceptsDrops = true
      newMorph.contents.adjustBounds()
      newMorph.setExtent new Point(350, 250)
      create newMorph
    
    menu.addItem "handle", ->
      create new HandleMorph()
    
    menu.addLine()
    menu.addItem "string", ->
      newMorph = new StringMorph("Hello, World!")
      newMorph.isEditable = true
      create newMorph
    
    # this is "The Lorelei" poem (From German).
    # see translation here:
    # http://poemsintranslation.blogspot.co.uk/2009/11/heinrich-heine-lorelei-from-german.html
    menu.addItem "text", ->
      newMorph = new TextMorph("Ich weiß nicht, was soll es bedeuten, dass ich so " +
        "traurig bin, ein Märchen aus uralten Zeiten, das " +
        "kommt mir nicht aus dem Sinn. Die Luft ist kühl " +
        "und es dunkelt, und ruhig fließt der Rhein; der " +
        "Gipfel des Berges funkelt im Abendsonnenschein. " +
        "Die schönste Jungfrau sitzet dort oben wunderbar, " +
        "ihr gold'nes Geschmeide blitzet, sie kämmt ihr " +
        "goldenes Haar, sie kämmt es mit goldenem Kamme, " +
        "und singt ein Lied dabei; das hat eine wundersame, " +
        "gewalt'ge Melodei. Den Schiffer im kleinen " +
        "Schiffe, ergreift es mit wildem Weh; er schaut " +
        "nicht die Felsenriffe, er schaut nur hinauf in " +
        "die Höh'. Ich glaube, die Wellen verschlingen " +
        "am Ende Schiffer und Kahn, und das hat mit ihrem " +
        "Singen, die Loreley getan.")
      newMorph.isEditable = true
      newMorph.maxWidth = 300
      create newMorph
    
    menu.addItem "speech bubble", ->
      newMorph = new SpeechBubbleMorph("Hello, World!")
      create newMorph
    
    menu.addLine()
    menu.addItem "gray scale palette", ->
      create new GrayPaletteMorph()
    
    menu.addItem "color palette", ->
      create new ColorPaletteMorph()
    
    menu.addItem "color picker", ->
      create new ColorPickerMorph()
    
    menu.addLine()
    menu.addItem "sensor demo", ->
      newMorph = new MouseSensorMorph()
      newMorph.setColor new Color(230, 200, 100)
      newMorph.edge = 35
      newMorph.border = 15
      newMorph.borderColor = new Color(200, 100, 50)
      newMorph.alpha = 0.2
      newMorph.setExtent new Point(100, 100)
      create newMorph
    
    menu.addItem "animation demo", ->
      foo = new BouncerMorph()
      foo.setPosition new Point(50, 20)
      foo.setExtent new Point(300, 200)
      foo.alpha = 0.9
      foo.speed = 3
      bar = new BouncerMorph()
      bar.setColor new Color(50, 50, 50)
      bar.setPosition new Point(80, 80)
      bar.setExtent new Point(80, 250)
      bar.type = "horizontal"
      bar.direction = "right"
      bar.alpha = 0.9
      bar.speed = 5
      baz = new BouncerMorph()
      baz.setColor new Color(20, 20, 20)
      baz.setPosition new Point(90, 140)
      baz.setExtent new Point(40, 30)
      baz.type = "horizontal"
      baz.direction = "right"
      baz.speed = 3
      garply = new BouncerMorph()
      garply.setColor new Color(200, 20, 20)
      garply.setPosition new Point(90, 140)
      garply.setExtent new Point(20, 20)
      garply.type = "vertical"
      garply.direction = "up"
      garply.speed = 8
      fred = new BouncerMorph()
      fred.setColor new Color(20, 200, 20)
      fred.setPosition new Point(120, 140)
      fred.setExtent new Point(20, 20)
      fred.type = "vertical"
      fred.direction = "down"
      fred.speed = 4
      bar.add garply
      bar.add baz
      foo.add fred
      foo.add bar
      create foo
    
    menu.addItem "pen", ->
      create new PenMorph()
    menu.addLine()
    menu.addItem "Layout tests", (->@layoutTestsMenu()), "sample morphs"
    menu.addLine()
    menu.addItem "view all...", ->
      newMorph = new MorphsListMorph()
      create newMorph
    menu.addItem "closing window", ->
      newMorph = new WorkspaceMorph()
      create newMorph

    if @customMorphs
      menu.addLine()
      @customMorphs().forEach (morph) ->
        menu.addItem morph.toString(), ->
          create morph
    
    menu.popUpAtHand()

  layoutTestsMenu: ->
    create = (aMorph) =>
      aMorph.isDraggable = true
      aMorph.pickUp()
    menu = new MenuMorph(@, "Layout tests")
    menu.addItem "test1", ->
      LayoutMorph.test1()
    menu.addItem "test2", ->
      LayoutMorph.test2()
    menu.addItem "test3", ->
      LayoutMorph.test3()
    menu.addItem "test4", ->
      LayoutMorph.test4()
    menu.popUpAtHand()
    
  
  toggleDevMode: ->
    @isDevMode = not @isDevMode
  
  minimiseAll: ->
    @children.forEach (child) ->
      child.minimise()
  
  showAllMinimised: ->
    @forAllChildrenBottomToTop (child) ->
      child.unminimise() if child.isMinimised
  
  about: ->
    @inform "Zombie Kernel\n\n" +
      "a lively Web GUI\ninspired by Squeak\n" +
      morphicVersion +
      "\n\nby Davide Della Casa" +
      "\n\nbased on morphic.js by" +
      "\nJens Mönig (jens@moenig.org)"
  
  edit: (aStringMorphOrTextMorph) ->
    # first off, if the Morph is not editable
    # then there is nothing to do
    # return null  unless aStringMorphOrTextMorph.isEditable

    # there is only one caret in the World, so destroy
    # the previous one if there was one.
    if @caret
      # empty the previously ongoing selection
      # if there was one.
      @lastEditedText = @caret.target
      @lastEditedText.clearSelection()  if @lastEditedText
      @caret = @caret.destroy()

    # create the new Caret
    @caret = new CaretMorph(aStringMorphOrTextMorph)
    aStringMorphOrTextMorph.parent.add @caret
    # this is the only place where the @keyboardEventsReceiver is set
    @keyboardEventsReceiver = @caret

    if WorldMorph.preferencesAndSettings.isTouchDevice and WorldMorph.preferencesAndSettings.useVirtualKeyboard
      @initVirtualKeyboard()
      # For touch devices, giving focus on the textbox causes
      # the keyboard to slide up, and since the page viewport
      # shrinks, the page is scrolled to where the texbox is.
      # So, it is important to position the textbox around
      # where the caret is, so that the changed text is going to
      # be visible rather than out of the viewport.
      pos = getDocumentPositionOf(@worldCanvas)
      @inputDOMElementForVirtualKeyboard.style.top = @caret.top() + pos.y + "px"
      @inputDOMElementForVirtualKeyboard.style.left = @caret.left() + pos.x + "px"
      @inputDOMElementForVirtualKeyboard.focus()
    if WorldMorph.preferencesAndSettings.useSliderForInput
      if !aStringMorphOrTextMorph.parentThatIsA(MenuMorph)
        @slide aStringMorphOrTextMorph
  
  # Editing can stop because of three reasons:
  #   cancel (user hits ESC)
  #   accept (on stringmorph, user hits enter)
  #   user clicks/drags another morph
  stopEditing: ->
    if @caret
      @lastEditedText = @caret.target
      @lastEditedText.clearSelection()
      @lastEditedText.escalateEvent "reactToEdit", @lastEditedText
      @caret = @caret.destroy()
    # the only place where the @keyboardEventsReceiver is unset
    # (and the hidden input is removed)
    @keyboardEventsReceiver = null
    if @inputDOMElementForVirtualKeyboard
      @inputDOMElementForVirtualKeyboard.blur()
      document.body.removeChild @inputDOMElementForVirtualKeyboard
      @inputDOMElementForVirtualKeyboard = null
    @worldCanvas.focus()
  
  slide: (aStringMorphOrTextMorph) ->
    # display a slider for numeric text entries
    val = parseFloat(aStringMorphOrTextMorph.text)
    val = 0  if isNaN(val)
    menu = new MenuMorph()
    slider = new SliderMorph(val - 25, val + 25, val, 10, "horizontal")
    slider.alpha = 1
    slider.color = new Color(225, 225, 225)
    slider.button.color = menu.borderColor
    slider.button.highlightColor = slider.button.color.copy()
    slider.button.highlightColor.b += 100
    slider.button.pressColor = slider.button.color.copy()
    slider.button.pressColor.b += 150
    slider.silentSetHeight WorldMorph.preferencesAndSettings.scrollBarSize
    slider.silentSetWidth WorldMorph.preferencesAndSettings.menuFontSize * 10
    slider.updateRendering()
    slider.action = (num) ->
      aStringMorphOrTextMorph.changed()
      aStringMorphOrTextMorph.text = Math.round(num).toString()
      aStringMorphOrTextMorph.updateRendering()
      aStringMorphOrTextMorph.changed()
      aStringMorphOrTextMorph.escalateEvent(
          'reactToSliderEdit',
          aStringMorphOrTextMorph
      )
    #
    menu.items.push slider
    menu.popup @, aStringMorphOrTextMorph.bottomLeft().add(new Point(0, 5))
  
  
  '''

# StringMorph /////////////////////////////////////////////////////////

# A StringMorph is a single line of text. It can only be left-aligned.
# REQUIRES WorldMorph

class StringMorph extends Morph

  text: null
  fontSize: null
  fontName: null
  fontStyle: null
  isBold: null
  isItalic: null
  isEditable: false
  isNumeric: null
  isPassword: false
  shadowOffset: null
  shadowColor: null
  isShowingBlanks: false
  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  blanksColor: new Color(180, 140, 140)
  #
  # Properties for text-editing
  isScrollable: true
  currentlySelecting: false
  startMark: null
  endMark: null
  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  markedTextColor: new Color(255, 255, 255)
  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  markedBackgoundColor: new Color(60, 60, 120)

  constructor: (
      text,
      @fontSize = 12,
      @fontStyle = "sans-serif",
      @isBold = false,
      @isItalic = false,
      @isNumeric = false,
      shadowOffset,
      @shadowColor,
      color,
      fontName
      ) ->
    # additional properties:
    @text = text or ((if (text is "") then "" else "StringMorph"))
    @fontName = fontName or WorldMorph.preferencesAndSettings.globalFontFamily
    @shadowOffset = shadowOffset or new Point(0, 0)
    #
    super()
    #
    # override inherited properites:
    @color = color or new Color(0, 0, 0)
    @noticesTransparentClick = true
  
  toString: ->
    # e.g. 'a StringMorph("Hello World")'
    firstPart = super()
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.hidingOfMorphsContentExtractInLabels
      return firstPart
    else
      return firstPart + " (\"" + @text.slice(0, 30) + "...\")"
  
  password: (letter, length) ->
    ans = ""
    for i in [0...length]
      ans += letter
    ans

  font: ->
    # answer a font string, e.g. 'bold italic 12px sans-serif'
    font = ""
    font = font + "bold "  if @isBold
    font = font + "italic "  if @isItalic
    font + @fontSize + "px " + ((if @fontName then @fontName + ", " else "")) + @fontStyle
  
  updateRendering: ->
    text = (if @isPassword then @password("*", @text.length) else @text)
    # initialize my surface property
    @image = newCanvas()
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    context.font = @font()
    context.textAlign = "left"
    context.textBaseline = "bottom"

    # set my extent based on the size of the text
    width = Math.max(context.measureText(text).width + Math.abs(@shadowOffset.x), 1)
    @bounds.corner = @bounds.origin.add(new Point(
      width, fontHeight(@fontSize) + Math.abs(@shadowOffset.y)))
    @image.width = width * pixelRatio
    @image.height = @height() * pixelRatio

    # changing the canvas size resets many of
    # the properties of the canvas, so we need to
    # re-initialise the font and alignments here
    context.scale pixelRatio, pixelRatio
    context.font = @font()
    context.textAlign = "left"
    context.textBaseline = "bottom"

    # first draw the shadow, if any
    if @shadowColor
      x = Math.max(@shadowOffset.x, 0)
      y = Math.max(@shadowOffset.y, 0)
      context.fillStyle = @shadowColor.toString()
      context.fillText text, x, fontHeight(@fontSize) + y
    #
    # now draw the actual text
    x = Math.abs(Math.min(@shadowOffset.x, 0))
    y = Math.abs(Math.min(@shadowOffset.y, 0))
    context.fillStyle = @color.toString()
    if @isShowingBlanks
      @renderWithBlanks context, x, fontHeight(@fontSize) + y
    else
      context.fillText text, x, fontHeight(@fontSize) + y
    #
    # draw the selection
    start = Math.min(@startMark, @endMark)
    stop = Math.max(@startMark, @endMark)
    for i in [start...stop]
      p = @slotCoordinates(i).subtract(@position())
      c = text.charAt(i)
      context.fillStyle = @markedBackgoundColor.toString()
      context.fillRect p.x, p.y, context.measureText(c).width + 1 + x,
        fontHeight(@fontSize) + y
      context.fillStyle = @markedTextColor.toString()
      context.fillText c, p.x + x, fontHeight(@fontSize) + y
    #
    # notify my parent of layout change
    # @parent.layoutSubmorphs()  if @parent.layoutSubmorphs  if @parent
  
  renderWithBlanks: (context, startX, y) ->
    # create the blank form
    drawBlank = ->
      context.drawImage blank, Math.round(x), 0
      x += space
    space = context.measureText(" ").width
    blank = newCanvas(new Point(space, @height()).scaleBy pixelRatio)
    ctx = blank.getContext("2d")
    words = @text.split(" ")
    x = startX or 0
    isFirst = true
    ctx.fillStyle = @blanksColor.toString()
    ctx.arc space / 2, blank.height / 2, space / 2, radians(0), radians(360)
    ctx.fill()
    #
    # render my text inserting blanks
    words.forEach (word) ->
      drawBlank()  unless isFirst
      isFirst = false
      if word isnt ""
        context.fillText word, x, y
        x += context.measureText(word).width
  
  
  # StringMorph mesuring:
  slotCoordinates: (slot) ->
    # answer the position point of the given index ("slot")
    # where the caret should be placed
    text = (if @isPassword then @password("*", @text.length) else @text)
    dest = Math.min(Math.max(slot, 0), text.length)
    context = @image.getContext("2d")
    xOffset = context.measureText(text.substring(0,dest)).width
    @pos = dest
    x = @left() + xOffset
    y = @top()
    new Point(x, y)
  
  slotAt: (aPoint) ->
    # answer the slot (index) closest to the given point
    # so the caret can be moved accordingly
    text = (if @isPassword then @password("*", @text.length) else @text)
    idx = 0
    charX = 0
    context = @image.getContext("2d")

    while aPoint.x - @left() > charX
      charX += context.measureText(text[idx]).width
      idx += 1
      if idx is text.length
        if (context.measureText(text).width - (context.measureText(text[idx - 1]).width / 2)) < (aPoint.x - @left())  
          return idx
    idx - 1
  
  upFrom: (slot) ->
    # answer the slot above the given one
    slot
  
  downFrom: (slot) ->
    # answer the slot below the given one
    slot
  
  startOfLine: ->
    # answer the first slot (index) of the line for the given slot
    0
  
  endOfLine: ->
    # answer the slot (index) indicating the EOL for the given slot
    @text.length

  rawHeight: ->
    # answer my corrected fontSize
    @height() / 1.2
    
  # StringMorph menus:
  developersMenu: ->
    menu = super()
    menu.addLine()
    menu.addItem "edit", (->
      @edit()
    )
    menu.addItem "font size...", (->
      @prompt menu.title + "\nfont\nsize:",
        @setFontSize, @fontSize.toString(), null, 6, 500, true
    ), "set this String's\nfont point size"
    menu.addItem "serif", (->@setSerif())  if @fontStyle isnt "serif"
    menu.addItem "sans-serif", (->@setSansSerif())  if @fontStyle isnt "sans-serif"

    if @isBold
      menu.addItem "normal weight", (->@toggleWeight())
    else
      menu.addItem "bold", (->@toggleWeight())

    if @isItalic
      menu.addItem "normal style", (->@toggleItalic())
    else
      menu.addItem "italic", (->@toggleItalic())

    if @isShowingBlanks
      menu.addItem "hide blanks", (->@toggleShowBlanks())
    else
      menu.addItem "show blanks", (->@toggleShowBlanks())

    if @isPassword
      menu.addItem "show characters", (->@toggleIsPassword())
    else
      menu.addItem "hide characters", (->@toggleIsPassword())

    menu
  
  toggleIsDraggable: ->
    # for context menu demo purposes
    @isDraggable = not @isDraggable
    if @isDraggable
      @disableSelecting()
    else
      @enableSelecting()
  
  toggleShowBlanks: ->
    @isShowingBlanks = not @isShowingBlanks
    @changed()
    @updateRendering()
    @changed()
  
  toggleWeight: ->
    @isBold = not @isBold
    @changed()
    @updateRendering()
    @changed()
  
  toggleItalic: ->
    @isItalic = not @isItalic
    @changed()
    @updateRendering()
    @changed()
  
  toggleIsPassword: ->
    @isPassword = not @isPassword
    @changed()
    @updateRendering()
    @changed()
  
  setSerif: ->
    @fontStyle = "serif"
    @changed()
    @updateRendering()
    @changed()
  
  setSansSerif: ->
    @fontStyle = "sans-serif"
    @changed()
    @updateRendering()
    @changed()
  
  setFontSize: (sizeOrMorphGivingSize) ->
    if sizeOrMorphGivingSize.getValue?
      size = sizeOrMorphGivingSize.getValue()
    else
      size = sizeOrMorphGivingSize

    # for context menu demo purposes
    if typeof size is "number"
      @fontSize = Math.round(Math.min(Math.max(size, 4), 500))
    else
      newSize = parseFloat(size)
      @fontSize = Math.round(Math.min(Math.max(newSize, 4), 500))  unless isNaN(newSize)
    @changed()
    @updateRendering()
    @changed()
  
  setText: (size) ->
    # for context menu demo purposes
    @text = Math.round(size).toString()
    @changed()
    @updateRendering()
    @changed()
  
  numericalSetters: ->
    # for context menu demo purposes
    ["setLeft", "setTop", "setAlphaScaled", "setFontSize", "setText"]
  
  
  # StringMorph editing:
  edit: ->
    @root().edit @

  editViaMenu: ->
    @root().editViaMenu @
  
  selection: ->
    start = Math.min(@startMark, @endMark)
    stop = Math.max(@startMark, @endMark)
    @text.slice start, stop
  
  selectionStartSlot: ->
    Math.min @startMark, @endMark
  
  clearSelection: ->
    @currentlySelecting = false
    @startMark = null
    @endMark = null
    @changed()
    @updateRendering()
    @changed()
  
  deleteSelection: ->
    text = @text
    start = Math.min(@startMark, @endMark)
    stop = Math.max(@startMark, @endMark)
    @text = text.slice(0, start) + text.slice(stop)
    @changed()
    @clearSelection()
  
  selectAll: ->
    @startMark = 0
    @endMark = @text.length
    @updateRendering()
    @changed()

  mouseDownLeft: (pos) ->
    if @isEditable
      @clearSelection()
    else
      @escalateEvent "mouseDownLeft", pos

  # Every time the user clicks on the text, a new edit()
  # is triggered, which creates a new caret.
  mouseClickLeft: (pos) ->
    caret = @root().caret;
    if @isEditable
      @edit()  unless @currentlySelecting
      if caret then caret.gotoPos pos
      @root().caret.gotoPos pos
      @currentlySelecting = true
    else
      @escalateEvent "mouseClickLeft", pos
  
  #mouseDoubleClick: ->
  #  alert "mouseDoubleClick!"

  enableSelecting: ->
    @mouseDownLeft = (pos) ->
      @clearSelection()
      if @isEditable and (not @isDraggable)
        @edit()
        @root().caret.gotoPos pos
        @startMark = @slotAt(pos)
        @endMark = @startMark
        @currentlySelecting = true
    
    @mouseMove = (pos) ->
      if @isEditable and @currentlySelecting and (not @isDraggable)
        newMark = @slotAt(pos)
        if newMark isnt @endMark
          @endMark = newMark
          @updateRendering()
          @changed()
  
  disableSelecting: ->
    # re-establish the original definition of the method
    @mouseDownLeft = StringMorph::mouseDownLeft
    delete @mouseMove

  @coffeeScriptSourceOfThisClass: '''
# StringMorph /////////////////////////////////////////////////////////

# A StringMorph is a single line of text. It can only be left-aligned.
# REQUIRES WorldMorph

class StringMorph extends Morph

  text: null
  fontSize: null
  fontName: null
  fontStyle: null
  isBold: null
  isItalic: null
  isEditable: false
  isNumeric: null
  isPassword: false
  shadowOffset: null
  shadowColor: null
  isShowingBlanks: false
  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  blanksColor: new Color(180, 140, 140)
  #
  # Properties for text-editing
  isScrollable: true
  currentlySelecting: false
  startMark: null
  endMark: null
  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  markedTextColor: new Color(255, 255, 255)
  # careful: this Color object is shared with all the instances of this class.
  # if you modify it, then all the objects will get the change
  # but if you replace it with a new Color, then that will only affect the
  # specific object instance. Same behaviour as with arrays.
  # see: https://github.com/jashkenas/coffee-script/issues/2501#issuecomment-7865333
  markedBackgoundColor: new Color(60, 60, 120)

  constructor: (
      text,
      @fontSize = 12,
      @fontStyle = "sans-serif",
      @isBold = false,
      @isItalic = false,
      @isNumeric = false,
      shadowOffset,
      @shadowColor,
      color,
      fontName
      ) ->
    # additional properties:
    @text = text or ((if (text is "") then "" else "StringMorph"))
    @fontName = fontName or WorldMorph.preferencesAndSettings.globalFontFamily
    @shadowOffset = shadowOffset or new Point(0, 0)
    #
    super()
    #
    # override inherited properites:
    @color = color or new Color(0, 0, 0)
    @noticesTransparentClick = true
  
  toString: ->
    # e.g. 'a StringMorph("Hello World")'
    firstPart = super()
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.IDLE and SystemTestsRecorderAndPlayer.hidingOfMorphsContentExtractInLabels
      return firstPart
    else
      return firstPart + " (\"" + @text.slice(0, 30) + "...\")"
  
  password: (letter, length) ->
    ans = ""
    for i in [0...length]
      ans += letter
    ans

  font: ->
    # answer a font string, e.g. 'bold italic 12px sans-serif'
    font = ""
    font = font + "bold "  if @isBold
    font = font + "italic "  if @isItalic
    font + @fontSize + "px " + ((if @fontName then @fontName + ", " else "")) + @fontStyle
  
  updateRendering: ->
    text = (if @isPassword then @password("*", @text.length) else @text)
    # initialize my surface property
    @image = newCanvas()
    context = @image.getContext("2d")
    context.scale pixelRatio, pixelRatio
    context.font = @font()
    context.textAlign = "left"
    context.textBaseline = "bottom"

    # set my extent based on the size of the text
    width = Math.max(context.measureText(text).width + Math.abs(@shadowOffset.x), 1)
    @bounds.corner = @bounds.origin.add(new Point(
      width, fontHeight(@fontSize) + Math.abs(@shadowOffset.y)))
    @image.width = width * pixelRatio
    @image.height = @height() * pixelRatio

    # changing the canvas size resets many of
    # the properties of the canvas, so we need to
    # re-initialise the font and alignments here
    context.scale pixelRatio, pixelRatio
    context.font = @font()
    context.textAlign = "left"
    context.textBaseline = "bottom"

    # first draw the shadow, if any
    if @shadowColor
      x = Math.max(@shadowOffset.x, 0)
      y = Math.max(@shadowOffset.y, 0)
      context.fillStyle = @shadowColor.toString()
      context.fillText text, x, fontHeight(@fontSize) + y
    #
    # now draw the actual text
    x = Math.abs(Math.min(@shadowOffset.x, 0))
    y = Math.abs(Math.min(@shadowOffset.y, 0))
    context.fillStyle = @color.toString()
    if @isShowingBlanks
      @renderWithBlanks context, x, fontHeight(@fontSize) + y
    else
      context.fillText text, x, fontHeight(@fontSize) + y
    #
    # draw the selection
    start = Math.min(@startMark, @endMark)
    stop = Math.max(@startMark, @endMark)
    for i in [start...stop]
      p = @slotCoordinates(i).subtract(@position())
      c = text.charAt(i)
      context.fillStyle = @markedBackgoundColor.toString()
      context.fillRect p.x, p.y, context.measureText(c).width + 1 + x,
        fontHeight(@fontSize) + y
      context.fillStyle = @markedTextColor.toString()
      context.fillText c, p.x + x, fontHeight(@fontSize) + y
    #
    # notify my parent of layout change
    # @parent.layoutSubmorphs()  if @parent.layoutSubmorphs  if @parent
  
  renderWithBlanks: (context, startX, y) ->
    # create the blank form
    drawBlank = ->
      context.drawImage blank, Math.round(x), 0
      x += space
    space = context.measureText(" ").width
    blank = newCanvas(new Point(space, @height()).scaleBy pixelRatio)
    ctx = blank.getContext("2d")
    words = @text.split(" ")
    x = startX or 0
    isFirst = true
    ctx.fillStyle = @blanksColor.toString()
    ctx.arc space / 2, blank.height / 2, space / 2, radians(0), radians(360)
    ctx.fill()
    #
    # render my text inserting blanks
    words.forEach (word) ->
      drawBlank()  unless isFirst
      isFirst = false
      if word isnt ""
        context.fillText word, x, y
        x += context.measureText(word).width
  
  
  # StringMorph mesuring:
  slotCoordinates: (slot) ->
    # answer the position point of the given index ("slot")
    # where the caret should be placed
    text = (if @isPassword then @password("*", @text.length) else @text)
    dest = Math.min(Math.max(slot, 0), text.length)
    context = @image.getContext("2d")
    xOffset = context.measureText(text.substring(0,dest)).width
    @pos = dest
    x = @left() + xOffset
    y = @top()
    new Point(x, y)
  
  slotAt: (aPoint) ->
    # answer the slot (index) closest to the given point
    # so the caret can be moved accordingly
    text = (if @isPassword then @password("*", @text.length) else @text)
    idx = 0
    charX = 0
    context = @image.getContext("2d")

    while aPoint.x - @left() > charX
      charX += context.measureText(text[idx]).width
      idx += 1
      if idx is text.length
        if (context.measureText(text).width - (context.measureText(text[idx - 1]).width / 2)) < (aPoint.x - @left())  
          return idx
    idx - 1
  
  upFrom: (slot) ->
    # answer the slot above the given one
    slot
  
  downFrom: (slot) ->
    # answer the slot below the given one
    slot
  
  startOfLine: ->
    # answer the first slot (index) of the line for the given slot
    0
  
  endOfLine: ->
    # answer the slot (index) indicating the EOL for the given slot
    @text.length

  rawHeight: ->
    # answer my corrected fontSize
    @height() / 1.2
    
  # StringMorph menus:
  developersMenu: ->
    menu = super()
    menu.addLine()
    menu.addItem "edit", (->
      @edit()
    )
    menu.addItem "font size...", (->
      @prompt menu.title + "\nfont\nsize:",
        @setFontSize, @fontSize.toString(), null, 6, 500, true
    ), "set this String's\nfont point size"
    menu.addItem "serif", (->@setSerif())  if @fontStyle isnt "serif"
    menu.addItem "sans-serif", (->@setSansSerif())  if @fontStyle isnt "sans-serif"

    if @isBold
      menu.addItem "normal weight", (->@toggleWeight())
    else
      menu.addItem "bold", (->@toggleWeight())

    if @isItalic
      menu.addItem "normal style", (->@toggleItalic())
    else
      menu.addItem "italic", (->@toggleItalic())

    if @isShowingBlanks
      menu.addItem "hide blanks", (->@toggleShowBlanks())
    else
      menu.addItem "show blanks", (->@toggleShowBlanks())

    if @isPassword
      menu.addItem "show characters", (->@toggleIsPassword())
    else
      menu.addItem "hide characters", (->@toggleIsPassword())

    menu
  
  toggleIsDraggable: ->
    # for context menu demo purposes
    @isDraggable = not @isDraggable
    if @isDraggable
      @disableSelecting()
    else
      @enableSelecting()
  
  toggleShowBlanks: ->
    @isShowingBlanks = not @isShowingBlanks
    @changed()
    @updateRendering()
    @changed()
  
  toggleWeight: ->
    @isBold = not @isBold
    @changed()
    @updateRendering()
    @changed()
  
  toggleItalic: ->
    @isItalic = not @isItalic
    @changed()
    @updateRendering()
    @changed()
  
  toggleIsPassword: ->
    @isPassword = not @isPassword
    @changed()
    @updateRendering()
    @changed()
  
  setSerif: ->
    @fontStyle = "serif"
    @changed()
    @updateRendering()
    @changed()
  
  setSansSerif: ->
    @fontStyle = "sans-serif"
    @changed()
    @updateRendering()
    @changed()
  
  setFontSize: (sizeOrMorphGivingSize) ->
    if sizeOrMorphGivingSize.getValue?
      size = sizeOrMorphGivingSize.getValue()
    else
      size = sizeOrMorphGivingSize

    # for context menu demo purposes
    if typeof size is "number"
      @fontSize = Math.round(Math.min(Math.max(size, 4), 500))
    else
      newSize = parseFloat(size)
      @fontSize = Math.round(Math.min(Math.max(newSize, 4), 500))  unless isNaN(newSize)
    @changed()
    @updateRendering()
    @changed()
  
  setText: (size) ->
    # for context menu demo purposes
    @text = Math.round(size).toString()
    @changed()
    @updateRendering()
    @changed()
  
  numericalSetters: ->
    # for context menu demo purposes
    ["setLeft", "setTop", "setAlphaScaled", "setFontSize", "setText"]
  
  
  # StringMorph editing:
  edit: ->
    @root().edit @

  editViaMenu: ->
    @root().editViaMenu @
  
  selection: ->
    start = Math.min(@startMark, @endMark)
    stop = Math.max(@startMark, @endMark)
    @text.slice start, stop
  
  selectionStartSlot: ->
    Math.min @startMark, @endMark
  
  clearSelection: ->
    @currentlySelecting = false
    @startMark = null
    @endMark = null
    @changed()
    @updateRendering()
    @changed()
  
  deleteSelection: ->
    text = @text
    start = Math.min(@startMark, @endMark)
    stop = Math.max(@startMark, @endMark)
    @text = text.slice(0, start) + text.slice(stop)
    @changed()
    @clearSelection()
  
  selectAll: ->
    @startMark = 0
    @endMark = @text.length
    @updateRendering()
    @changed()

  mouseDownLeft: (pos) ->
    if @isEditable
      @clearSelection()
    else
      @escalateEvent "mouseDownLeft", pos

  # Every time the user clicks on the text, a new edit()
  # is triggered, which creates a new caret.
  mouseClickLeft: (pos) ->
    caret = @root().caret;
    if @isEditable
      @edit()  unless @currentlySelecting
      if caret then caret.gotoPos pos
      @root().caret.gotoPos pos
      @currentlySelecting = true
    else
      @escalateEvent "mouseClickLeft", pos
  
  #mouseDoubleClick: ->
  #  alert "mouseDoubleClick!"

  enableSelecting: ->
    @mouseDownLeft = (pos) ->
      @clearSelection()
      if @isEditable and (not @isDraggable)
        @edit()
        @root().caret.gotoPos pos
        @startMark = @slotAt(pos)
        @endMark = @startMark
        @currentlySelecting = true
    
    @mouseMove = (pos) ->
      if @isEditable and @currentlySelecting and (not @isDraggable)
        newMark = @slotAt(pos)
        if newMark isnt @endMark
          @endMark = newMark
          @updateRendering()
          @changed()
  
  disableSelecting: ->
    # re-establish the original definition of the method
    @mouseDownLeft = StringMorph::mouseDownLeft
    delete @mouseMove
  '''

# Holds information about browser and machine
# Note that some of these could
# change during user session.

class SystemInfo

  userAgent: null
  screenWidth: null
  screenHeight: null
  screenColorDepth: null
  screenPixelRatio: null
  appCodeName: null
  appName: null
  appVersion: null
  cookieEnabled: null
  platform: null
  systemLanguage: null

  constructor: ->
    @userAgent = navigator.userAgent
    @screenWidth = window.screen.width
    @screenHeight = window.screen.height
    @screenColorDepth = window.screen.colorDepth
    @screenPixelRatio = window.devicePixelRatio
    @appCodeName = navigator.appCodeName
    @appName = navigator.appName
    @appVersion = navigator.appVersion
    @cookieEnabled = navigator.cookieEnabled
    @platform = navigator.platform
    @systemLanguage = navigator.systemLanguage

  @coffeeScriptSourceOfThisClass: '''
# Holds information about browser and machine
# Note that some of these could
# change during user session.

class SystemInfo

  userAgent: null
  screenWidth: null
  screenHeight: null
  screenColorDepth: null
  screenPixelRatio: null
  appCodeName: null
  appName: null
  appVersion: null
  cookieEnabled: null
  platform: null
  systemLanguage: null

  constructor: ->
    @userAgent = navigator.userAgent
    @screenWidth = window.screen.width
    @screenHeight = window.screen.height
    @screenColorDepth = window.screen.colorDepth
    @screenPixelRatio = window.devicePixelRatio
    @appCodeName = navigator.appCodeName
    @appName = navigator.appName
    @appVersion = navigator.appVersion
    @cookieEnabled = navigator.cookieEnabled
    @platform = navigator.platform
    @systemLanguage = navigator.systemLanguage
  '''

# The SystemTests recorder collects a number
# of commands from the user and puts them in a
# queue. This is the superclass of all the
# possible commands.


class SystemTestsCommand
  testCommandName: ''
  millisecondsSincePreviousCommand: 0

  constructor: (systemTestsRecorderAndPlayer) ->
    @millisecondsSincePreviousCommand = (new Date().getTime()) - systemTestsRecorderAndPlayer.timeOfPreviouslyRecordedCommand

  @coffeeScriptSourceOfThisClass: '''
# The SystemTests recorder collects a number
# of commands from the user and puts them in a
# queue. This is the superclass of all the
# possible commands.


class SystemTestsCommand
  testCommandName: ''
  millisecondsSincePreviousCommand: 0

  constructor: (systemTestsRecorderAndPlayer) ->
    @millisecondsSincePreviousCommand = (new Date().getTime()) - systemTestsRecorderAndPlayer.timeOfPreviouslyRecordedCommand
  '''

# 


class SystemTestsCommandCheckNumberOfItemsInMenu extends SystemTestsCommand
  numberOfItemsInMenu: 0

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.checkNumberOfItemsInMenu(commandBeingPlayed.numberOfItemsInMenu)

  constructor: (@numberOfItemsInMenu, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandCheckNumberOfItemsInMenu"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandCheckNumberOfItemsInMenu extends SystemTestsCommand
  numberOfItemsInMenu: 0

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.checkNumberOfItemsInMenu(commandBeingPlayed.numberOfItemsInMenu)

  constructor: (@numberOfItemsInMenu, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandCheckNumberOfItemsInMenu"
  '''

# 


class SystemTestsCommandCheckStringsOfItemsInMenuOrderImportant extends SystemTestsCommand
  stringOfItemsInMenuInOriginalOrder: []

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.checkStringsOfItemsInMenuOrderImportant(commandBeingPlayed.stringOfItemsInMenuInOriginalOrder)

  constructor: (@stringOfItemsInMenuInOriginalOrder, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandCheckStringsOfItemsInMenuOrderImportant"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandCheckStringsOfItemsInMenuOrderImportant extends SystemTestsCommand
  stringOfItemsInMenuInOriginalOrder: []

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.checkStringsOfItemsInMenuOrderImportant(commandBeingPlayed.stringOfItemsInMenuInOriginalOrder)

  constructor: (@stringOfItemsInMenuInOriginalOrder, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandCheckStringsOfItemsInMenuOrderImportant"
  '''

# 


class SystemTestsCommandCheckStringsOfItemsInMenuOrderUnimportant extends SystemTestsCommand
  stringOfItemsInMenuInOriginalOrder: []

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.checkStringsOfItemsInMenuOrderUnimportant(commandBeingPlayed.stringOfItemsInMenuInOriginalOrder)

  constructor: (@stringOfItemsInMenuInOriginalOrder, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandCheckStringsOfItemsInMenuOrderUnimportant"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandCheckStringsOfItemsInMenuOrderUnimportant extends SystemTestsCommand
  stringOfItemsInMenuInOriginalOrder: []

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.checkStringsOfItemsInMenuOrderUnimportant(commandBeingPlayed.stringOfItemsInMenuInOriginalOrder)

  constructor: (@stringOfItemsInMenuInOriginalOrder, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandCheckStringsOfItemsInMenuOrderUnimportant"
  '''

# 


class SystemTestsCommandCopy extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.worldMorph.processCopy null

  constructor: (@clipboardText, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandCopy"
  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandCopy extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.worldMorph.processCopy null

  constructor: (@clipboardText, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandCopy"  '''

# 


class SystemTestsCommandDoNothing extends SystemTestsCommand
  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->

  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandDoNothing"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandDoNothing extends SystemTestsCommand
  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->

  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandDoNothing"
  '''

# 


class SystemTestsCommandKeyDown extends SystemTestsCommand
  scanCode: null
  shiftKey: null
  ctrlKey: null
  altKey: null
  metaKey: null

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    console.log "replaying key"
    systemTestsRecorderAndPlayer.worldMorph.processKeydown null, commandBeingPlayed.scanCode, commandBeingPlayed.shiftKey, commandBeingPlayed.ctrlKey, commandBeingPlayed.altKey, commandBeingPlayed.metaKey


  constructor: (@scanCode, @shiftKey, @ctrlKey, @altKey, @metaKey, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandKeyDown"
  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandKeyDown extends SystemTestsCommand
  scanCode: null
  shiftKey: null
  ctrlKey: null
  altKey: null
  metaKey: null

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    console.log "replaying key"
    systemTestsRecorderAndPlayer.worldMorph.processKeydown null, commandBeingPlayed.scanCode, commandBeingPlayed.shiftKey, commandBeingPlayed.ctrlKey, commandBeingPlayed.altKey, commandBeingPlayed.metaKey


  constructor: (@scanCode, @shiftKey, @ctrlKey, @altKey, @metaKey, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandKeyDown"  '''

# 


class SystemTestsCommandKeyPress extends SystemTestsCommand
  charCode: null
  symbol: null
  shiftKey: null
  ctrlKey: null
  altKey: null
  metaKey: null

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    console.log "replaying key"
    systemTestsRecorderAndPlayer.worldMorph.processKeypress null, commandBeingPlayed.charCode, commandBeingPlayed.symbol, commandBeingPlayed.shiftKey, commandBeingPlayed.ctrlKey, commandBeingPlayed.altKey, commandBeingPlayed.metaKey


  constructor: (@charCode, @symbol, @shiftKey, @ctrlKey, @altKey, @metaKey, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandKeyPress"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandKeyPress extends SystemTestsCommand
  charCode: null
  symbol: null
  shiftKey: null
  ctrlKey: null
  altKey: null
  metaKey: null

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    console.log "replaying key"
    systemTestsRecorderAndPlayer.worldMorph.processKeypress null, commandBeingPlayed.charCode, commandBeingPlayed.symbol, commandBeingPlayed.shiftKey, commandBeingPlayed.ctrlKey, commandBeingPlayed.altKey, commandBeingPlayed.metaKey


  constructor: (@charCode, @symbol, @shiftKey, @ctrlKey, @altKey, @metaKey, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandKeyPress"
  '''

# 


class SystemTestsCommandKeyUp extends SystemTestsCommand
  scanCode: null
  shiftKey: null
  ctrlKey: null
  altKey: null
  metaKey: null

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    console.log "replaying key"
    systemTestsRecorderAndPlayer.worldMorph.processKeyup null, commandBeingPlayed.scanCode, commandBeingPlayed.shiftKey, commandBeingPlayed.ctrlKey, commandBeingPlayed.altKey, commandBeingPlayed.metaKey


  constructor: (@scanCode, @shiftKey, @ctrlKey, @altKey, @metaKey, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandKeyUp"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandKeyUp extends SystemTestsCommand
  scanCode: null
  shiftKey: null
  ctrlKey: null
  altKey: null
  metaKey: null

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    console.log "replaying key"
    systemTestsRecorderAndPlayer.worldMorph.processKeyup null, commandBeingPlayed.scanCode, commandBeingPlayed.shiftKey, commandBeingPlayed.ctrlKey, commandBeingPlayed.altKey, commandBeingPlayed.metaKey


  constructor: (@scanCode, @shiftKey, @ctrlKey, @altKey, @metaKey, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandKeyUp"
  '''

# 


class SystemTestsCommandLeftOrRightClickOnMenuItem extends SystemTestsCommand
  whichMouseButtonPressed = ""
  textLabelOfClickedItem: 0
  # there might be multiple instances of
  # the same text label so we count
  # which one it is
  textLabelOccurrenceNumber: 0

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.handMorph.leftOrRightClickOnMenuItemWithText(commandBeingPlayed.whichMouseButtonPressed, commandBeingPlayed.textLabelOfClickedItem, commandBeingPlayed.textLabelOccurrenceNumber)

  constructor: (@whichMouseButtonPressed, @textLabelOfClickedItem, @textLabelOccurrenceNumber, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandLeftOrRightClickOnMenuItem"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandLeftOrRightClickOnMenuItem extends SystemTestsCommand
  whichMouseButtonPressed = ""
  textLabelOfClickedItem: 0
  # there might be multiple instances of
  # the same text label so we count
  # which one it is
  textLabelOccurrenceNumber: 0

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.handMorph.leftOrRightClickOnMenuItemWithText(commandBeingPlayed.whichMouseButtonPressed, commandBeingPlayed.textLabelOfClickedItem, commandBeingPlayed.textLabelOccurrenceNumber)

  constructor: (@whichMouseButtonPressed, @textLabelOfClickedItem, @textLabelOccurrenceNumber, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandLeftOrRightClickOnMenuItem"
  '''

# 


class SystemTestsCommandMouseDown extends SystemTestsCommand
  button: null
  ctrlKey: null
  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.handMorph.processMouseDown(commandBeingPlayed.button, commandBeingPlayed.ctrlKey)

  transformIntoDoNothingCommand: ->
    @testCommandName = "SystemTestsCommandDoNothing"

  constructor: (@button, @ctrlKey, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandMouseDown"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandMouseDown extends SystemTestsCommand
  button: null
  ctrlKey: null
  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.handMorph.processMouseDown(commandBeingPlayed.button, commandBeingPlayed.ctrlKey)

  transformIntoDoNothingCommand: ->
    @testCommandName = "SystemTestsCommandDoNothing"

  constructor: (@button, @ctrlKey, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandMouseDown"
  '''

# 


class SystemTestsCommandMouseMove extends SystemTestsCommand
  mouseX: null
  mouseY: null
  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.handMorph.processMouseMove(commandBeingPlayed.mouseX, commandBeingPlayed.mouseY)

  constructor: (@mouseX, @mouseY, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandMouseMove"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandMouseMove extends SystemTestsCommand
  mouseX: null
  mouseY: null
  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.handMorph.processMouseMove(commandBeingPlayed.mouseX, commandBeingPlayed.mouseY)

  constructor: (@mouseX, @mouseY, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandMouseMove"
  '''

# 


class SystemTestsCommandMouseUp extends SystemTestsCommand
  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.handMorph.processMouseUp()

  transformIntoDoNothingCommand: ->
    @testCommandName = "SystemTestsCommandDoNothing"

  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandMouseUp"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandMouseUp extends SystemTestsCommand
  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.handMorph.processMouseUp()

  transformIntoDoNothingCommand: ->
    @testCommandName = "SystemTestsCommandDoNothing"

  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandMouseUp"
  '''

# 


class SystemTestsCommandOpenContextMenu extends SystemTestsCommand
  morphToOpenContextMenuAgainst_UniqueIDString: null

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.handMorph.openContextMenuAtPointer (Morph.morphFromUniqueIDString commandBeingPlayed.morphToOpenContextMenuAgainst_UniqueIDString)


  constructor: (@morphToOpenContextMenuAgainst_UniqueIDString, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandOpenContextMenu"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandOpenContextMenu extends SystemTestsCommand
  morphToOpenContextMenuAgainst_UniqueIDString: null

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.handMorph.openContextMenuAtPointer (Morph.morphFromUniqueIDString commandBeingPlayed.morphToOpenContextMenuAgainst_UniqueIDString)


  constructor: (@morphToOpenContextMenuAgainst_UniqueIDString, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandOpenContextMenu"
  '''

# 


class SystemTestsCommandPaste extends SystemTestsCommand
  clipboardText: null

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    console.log "test player inserting text: " + commandBeingPlayed.clipboardText
    systemTestsRecorderAndPlayer.worldMorph.processPaste null, commandBeingPlayed.clipboardText


  constructor: (@clipboardText, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandPaste"
  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandPaste extends SystemTestsCommand
  clipboardText: null

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    console.log "test player inserting text: " + commandBeingPlayed.clipboardText
    systemTestsRecorderAndPlayer.worldMorph.processPaste null, commandBeingPlayed.clipboardText


  constructor: (@clipboardText, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandPaste"  '''

# 

class SystemTestsCommandResetWorld extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.worldMorph.resetWorld()

  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandResetWorld"

  @coffeeScriptSourceOfThisClass: '''
# 

class SystemTestsCommandResetWorld extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.worldMorph.resetWorld()

  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandResetWorld"
  '''

#


class SystemTestsCommandScreenshot extends SystemTestsCommand
  screenShotImageName: null
  # The screenshot can be of the entire
  # world or of a particular morph (through
  # the "take pic" menu entry.
  # The screenshotTakenOfAParticularMorph flag
  # remembers which case we are in.
  # In the case that the screenshot is
  # of a particular morph, the comparison
  # will have to wait for the world
  # to provide the image data (the take pic command
  # will do it)
  screenshotTakenOfAParticularMorph: false
  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.compareScreenshots(commandBeingPlayed.screenShotImageName, commandBeingPlayed.screenshotTakenOfAParticularMorph)


  constructor: (@screenShotImageName, systemTestsRecorderAndPlayer, @screenshotTakenOfAParticularMorph = false ) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandScreenshot"

  @coffeeScriptSourceOfThisClass: '''
#


class SystemTestsCommandScreenshot extends SystemTestsCommand
  screenShotImageName: null
  # The screenshot can be of the entire
  # world or of a particular morph (through
  # the "take pic" menu entry.
  # The screenshotTakenOfAParticularMorph flag
  # remembers which case we are in.
  # In the case that the screenshot is
  # of a particular morph, the comparison
  # will have to wait for the world
  # to provide the image data (the take pic command
  # will do it)
  screenshotTakenOfAParticularMorph: false
  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.compareScreenshots(commandBeingPlayed.screenShotImageName, commandBeingPlayed.screenshotTakenOfAParticularMorph)


  constructor: (@screenShotImageName, systemTestsRecorderAndPlayer, @screenshotTakenOfAParticularMorph = false ) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandScreenshot"
  '''

# 


class SystemTestsCommandShowComment extends SystemTestsCommand
  message: ""

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    SystemTestsControlPanelUpdater.addMessageToTestCommentsConsole commandBeingPlayed.message

  constructor: (@message, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandShowComment"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandShowComment extends SystemTestsCommand
  message: ""

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    SystemTestsControlPanelUpdater.addMessageToTestCommentsConsole commandBeingPlayed.message

  constructor: (@message, systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandShowComment"
  '''

# 


class SystemTestsCommandTurnOffAlignmentOfMorphIDsMechanism extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOffAlignmentOfMorphIDsMechanism()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOffAlignmentOfMorphIDsMechanism"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandTurnOffAlignmentOfMorphIDsMechanism extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOffAlignmentOfMorphIDsMechanism()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOffAlignmentOfMorphIDsMechanism"
  '''

# 


class SystemTestsCommandTurnOffAnimationsPacingControl extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOffAnimationsPacingControl()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOffAnimationsPacingControl"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandTurnOffAnimationsPacingControl extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOffAnimationsPacingControl()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOffAnimationsPacingControl"
  '''

# 


class SystemTestsCommandTurnOffHidingOfMorphsContentExtractInLabels extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOffHidingOfMorphsContentExtractInLabels()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOffHidingOfMorphsContentExtractInLabels"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandTurnOffHidingOfMorphsContentExtractInLabels extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOffHidingOfMorphsContentExtractInLabels()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOffHidingOfMorphsContentExtractInLabels"
  '''

# 


class SystemTestsCommandTurnOffHidingOfMorphsGeometryInfoInLabels extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOffHidingOfMorphsGeometryInfoInLabels()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOffHidingOfMorphsGeometryInfoInLabels"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandTurnOffHidingOfMorphsGeometryInfoInLabels extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOffHidingOfMorphsGeometryInfoInLabels()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOffHidingOfMorphsGeometryInfoInLabels"
  '''

# 


class SystemTestsCommandTurnOffHidingOfMorphsNumberIDInLabels extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOffHidingOfMorphsNumberIDInLabels()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOffHidingOfMorphsNumberIDInLabels"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandTurnOffHidingOfMorphsNumberIDInLabels extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOffHidingOfMorphsNumberIDInLabels()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOffHidingOfMorphsNumberIDInLabels"
  '''

# 


class SystemTestsCommandTurnOnAlignmentOfMorphIDsMechanism extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOnAlignmentOfMorphIDsMechanism()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOnAlignmentOfMorphIDsMechanism"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandTurnOnAlignmentOfMorphIDsMechanism extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOnAlignmentOfMorphIDsMechanism()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOnAlignmentOfMorphIDsMechanism"
  '''

# 


class SystemTestsCommandTurnOnAnimationsPacingControl extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOnAnimationsPacingControl()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOnAnimationsPacingControl"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandTurnOnAnimationsPacingControl extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOnAnimationsPacingControl()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOnAnimationsPacingControl"
  '''

# 


class SystemTestsCommandTurnOnHidingOfMorphsContentExtractInLabels extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOnHidingOfMorphsContentExtractInLabels()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOnHidingOfMorphsContentExtractInLabels"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandTurnOnHidingOfMorphsContentExtractInLabels extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOnHidingOfMorphsContentExtractInLabels()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOnHidingOfMorphsContentExtractInLabels"
  '''

# 


class SystemTestsCommandTurnOnHidingOfMorphsGeometryInfoInLabels extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOnHidingOfMorphsGeometryInfoInLabels()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOnHidingOfMorphsGeometryInfoInLabels"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandTurnOnHidingOfMorphsGeometryInfoInLabels extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOnHidingOfMorphsGeometryInfoInLabels()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOnHidingOfMorphsGeometryInfoInLabels"
  '''

# 


class SystemTestsCommandTurnOnHidingOfMorphsNumberIDInLabels extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOnHidingOfMorphsNumberIDInLabels()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOnHidingOfMorphsNumberIDInLabels"

  @coffeeScriptSourceOfThisClass: '''
# 


class SystemTestsCommandTurnOnHidingOfMorphsNumberIDInLabels extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOnHidingOfMorphsNumberIDInLabels()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOnHidingOfMorphsNumberIDInLabels"
  '''

# Manages the controls of the System Tests
# e.g. all the links/buttons to trigger commands
# when recording tests such as
#  - start recording tests
#  - stop recording tests
#  - take screenshot
#  - save test files
#  - place the mouse over a morph with particular ID...


class SystemTestsControlPanelUpdater

  # Create the div where the controls will go
  # and make it float to the right of the canvas.
  # This requires tweaking the css of the canvas
  # as well.

  SystemTestsControlPanelDiv: null
  @SystemTestsControlPanelOutputConsoleDiv: null

  @addMessageToSystemTestsConsole: (theText) ->
    SystemTestsControlPanelUpdater.SystemTestsControlPanelOutputConsoleDiv.innerHTML = SystemTestsControlPanelUpdater.SystemTestsControlPanelOutputConsoleDiv.innerHTML + theText + "</br>";

  @addMessageToTestCommentsConsole: (theText) ->
    SystemTestsControlPanelUpdater.SystemTestsControlPanelTestCommentsOutputConsoleDiv.innerHTML = SystemTestsControlPanelUpdater.SystemTestsControlPanelTestCommentsOutputConsoleDiv.innerHTML + theText + "</br>";

  addLink: (theText, theFunction) ->
    aTag = document.createElement("a")
    aTag.setAttribute "href", "#"
    aTag.innerHTML = theText
    aTag.onclick = theFunction
    @SystemTestsControlPanelDiv.appendChild aTag
    br = document.createElement('br')
    @SystemTestsControlPanelDiv.appendChild(br);

  addOnOffSwitchLink: (theText, onShortcut, offShortcut, onAction, offAction) ->
    #aLittleDiv = document.createElement("div")
    
    aLittleSpan = document.createElement("span")
    aLittleSpan.innerHTML = theText + " "

    aLittleSpacerSpan = document.createElement("span")
    aLittleSpacerSpan.innerHTML = " "

    onLinkElement = document.createElement("a")
    onLinkElement.setAttribute "href", "#"
    onLinkElement.innerHTML = "on:"+onShortcut
    onLinkElement.onclick = onAction

    offLinkElement = document.createElement("a")
    offLinkElement.setAttribute "href", "#"
    offLinkElement.innerHTML = "off:"+offShortcut
    offLinkElement.onclick = offAction

    @SystemTestsControlPanelDiv.appendChild aLittleSpan
    @SystemTestsControlPanelDiv.appendChild onLinkElement
    @SystemTestsControlPanelDiv.appendChild aLittleSpacerSpan
    @SystemTestsControlPanelDiv.appendChild offLinkElement

    br = document.createElement('br')
    @SystemTestsControlPanelDiv.appendChild(br);

  addOutputPanel: (nameOfPanel) ->
    SystemTestsControlPanelUpdater[nameOfPanel] = document.createElement('div')
    SystemTestsControlPanelUpdater[nameOfPanel].id = nameOfPanel
    SystemTestsControlPanelUpdater[nameOfPanel].style.cssText = 'height: 150px; border: 1px solid red; overflow: hidden; overflow-y: scroll;'
    document.body.appendChild(SystemTestsControlPanelUpdater[nameOfPanel])

  constructor: ->
    @SystemTestsControlPanelDiv = document.createElement('div')
    @SystemTestsControlPanelDiv.id = "SystemTestsControlPanel"
    @SystemTestsControlPanelDiv.style.cssText = 'border: 1px solid green; overflow: hidden;'
    document.body.appendChild(@SystemTestsControlPanelDiv)

    @addOutputPanel "SystemTestsControlPanelOutputConsoleDiv"
    @addOutputPanel "SystemTestsControlPanelTestCommentsOutputConsoleDiv"

    theCanvasDiv = document.getElementById('world')
    # one of these is for IE and the other one
    # for everybody else
    theCanvasDiv.style.styleFloat = 'left';
    theCanvasDiv.style.cssFloat = 'left';

    # The spirit of these links is that it would
    # be really inconvenient to trigger
    # these commands using menus during the test.
    # For example it would be inconvenient to stop
    # the tests recording by selecting the command
    # via e menu: a bunch of mouse actions would be
    # recorded, exposing as well to the risk of the
    # menu items changing.
    @addLink "alt+d: reset world", (-> window.world.systemTestsRecorderAndPlayer.resetWorld())
    @addOnOffSwitchLink "tie animations to test step", "alt+e", "alt+u", (-> window.world.systemTestsRecorderAndPlayer.turnOnAnimationsPacingControl()), (-> window.world.systemTestsRecorderAndPlayer.turnOffAnimationsPacingControl())
    @addOnOffSwitchLink "periodically align Morph IDs", "-", "-", (-> window.world.systemTestsRecorderAndPlayer.turnOnAlignmentOfMorphIDsMechanism()), (-> window.world.systemTestsRecorderAndPlayer.turnOffAlignmentOfMorphIDsMechanism())
    @addOnOffSwitchLink "hide Morph geometry in labels", "-", "-", (-> window.world.systemTestsRecorderAndPlayer.turnOnHidingOfMorphsGeometryInfoInLabels()), (-> window.world.systemTestsRecorderAndPlayer.turnOffHidingOfMorphsGeometryInfoInLabels())

    @addOnOffSwitchLink "hide Morph content extract in labels", "-", "-", (-> window.world.systemTestsRecorderAndPlayer.turnOnHidingOfMorphsContentExtractInLabels()), (-> window.world.systemTestsRecorderAndPlayer.turnOffHidingOfMorphsContentExtractInLabels())

    @addOnOffSwitchLink "hide Morph number ID in labels", "-", "-", (-> window.world.systemTestsRecorderAndPlayer.turnOnHidingOfMorphsNumberIDInLabels()), (-> window.world.systemTestsRecorderAndPlayer.turnOffHidingOfMorphsNumberIDInLabels())

    @addLink "alt+c: take screenshot", (-> window.world.systemTestsRecorderAndPlayer.takeScreenshot())
    @addLink "alt+k: check number of items in menu", (-> window.world.systemTestsRecorderAndPlayer.checkNumberOfItemsInMenu())
    @addLink "alt+a: check menu entries (in order)", (-> window.world.systemTestsRecorderAndPlayer.checkStringsOfItemsInMenuOrderImportant())
    @addLink "alt+z: check menu entries (any order)", (-> window.world.systemTestsRecorderAndPlayer.checkStringsOfItemsInMenuOrderUnimportant())
    @addLink "alt+m: add test comment", (-> window.world.systemTestsRecorderAndPlayer.addTestComment())
    @addLink "alt+t: stop test recording", (-> window.world.systemTestsRecorderAndPlayer.stopTestRecording())
    



    

  @coffeeScriptSourceOfThisClass: '''
# Manages the controls of the System Tests
# e.g. all the links/buttons to trigger commands
# when recording tests such as
#  - start recording tests
#  - stop recording tests
#  - take screenshot
#  - save test files
#  - place the mouse over a morph with particular ID...


class SystemTestsControlPanelUpdater

  # Create the div where the controls will go
  # and make it float to the right of the canvas.
  # This requires tweaking the css of the canvas
  # as well.

  SystemTestsControlPanelDiv: null
  @SystemTestsControlPanelOutputConsoleDiv: null

  @addMessageToSystemTestsConsole: (theText) ->
    SystemTestsControlPanelUpdater.SystemTestsControlPanelOutputConsoleDiv.innerHTML = SystemTestsControlPanelUpdater.SystemTestsControlPanelOutputConsoleDiv.innerHTML + theText + "</br>";

  @addMessageToTestCommentsConsole: (theText) ->
    SystemTestsControlPanelUpdater.SystemTestsControlPanelTestCommentsOutputConsoleDiv.innerHTML = SystemTestsControlPanelUpdater.SystemTestsControlPanelTestCommentsOutputConsoleDiv.innerHTML + theText + "</br>";

  addLink: (theText, theFunction) ->
    aTag = document.createElement("a")
    aTag.setAttribute "href", "#"
    aTag.innerHTML = theText
    aTag.onclick = theFunction
    @SystemTestsControlPanelDiv.appendChild aTag
    br = document.createElement('br')
    @SystemTestsControlPanelDiv.appendChild(br);

  addOnOffSwitchLink: (theText, onShortcut, offShortcut, onAction, offAction) ->
    #aLittleDiv = document.createElement("div")
    
    aLittleSpan = document.createElement("span")
    aLittleSpan.innerHTML = theText + " "

    aLittleSpacerSpan = document.createElement("span")
    aLittleSpacerSpan.innerHTML = " "

    onLinkElement = document.createElement("a")
    onLinkElement.setAttribute "href", "#"
    onLinkElement.innerHTML = "on:"+onShortcut
    onLinkElement.onclick = onAction

    offLinkElement = document.createElement("a")
    offLinkElement.setAttribute "href", "#"
    offLinkElement.innerHTML = "off:"+offShortcut
    offLinkElement.onclick = offAction

    @SystemTestsControlPanelDiv.appendChild aLittleSpan
    @SystemTestsControlPanelDiv.appendChild onLinkElement
    @SystemTestsControlPanelDiv.appendChild aLittleSpacerSpan
    @SystemTestsControlPanelDiv.appendChild offLinkElement

    br = document.createElement('br')
    @SystemTestsControlPanelDiv.appendChild(br);

  addOutputPanel: (nameOfPanel) ->
    SystemTestsControlPanelUpdater[nameOfPanel] = document.createElement('div')
    SystemTestsControlPanelUpdater[nameOfPanel].id = nameOfPanel
    SystemTestsControlPanelUpdater[nameOfPanel].style.cssText = 'height: 150px; border: 1px solid red; overflow: hidden; overflow-y: scroll;'
    document.body.appendChild(SystemTestsControlPanelUpdater[nameOfPanel])

  constructor: ->
    @SystemTestsControlPanelDiv = document.createElement('div')
    @SystemTestsControlPanelDiv.id = "SystemTestsControlPanel"
    @SystemTestsControlPanelDiv.style.cssText = 'border: 1px solid green; overflow: hidden;'
    document.body.appendChild(@SystemTestsControlPanelDiv)

    @addOutputPanel "SystemTestsControlPanelOutputConsoleDiv"
    @addOutputPanel "SystemTestsControlPanelTestCommentsOutputConsoleDiv"

    theCanvasDiv = document.getElementById('world')
    # one of these is for IE and the other one
    # for everybody else
    theCanvasDiv.style.styleFloat = 'left';
    theCanvasDiv.style.cssFloat = 'left';

    # The spirit of these links is that it would
    # be really inconvenient to trigger
    # these commands using menus during the test.
    # For example it would be inconvenient to stop
    # the tests recording by selecting the command
    # via e menu: a bunch of mouse actions would be
    # recorded, exposing as well to the risk of the
    # menu items changing.
    @addLink "alt+d: reset world", (-> window.world.systemTestsRecorderAndPlayer.resetWorld())
    @addOnOffSwitchLink "tie animations to test step", "alt+e", "alt+u", (-> window.world.systemTestsRecorderAndPlayer.turnOnAnimationsPacingControl()), (-> window.world.systemTestsRecorderAndPlayer.turnOffAnimationsPacingControl())
    @addOnOffSwitchLink "periodically align Morph IDs", "-", "-", (-> window.world.systemTestsRecorderAndPlayer.turnOnAlignmentOfMorphIDsMechanism()), (-> window.world.systemTestsRecorderAndPlayer.turnOffAlignmentOfMorphIDsMechanism())
    @addOnOffSwitchLink "hide Morph geometry in labels", "-", "-", (-> window.world.systemTestsRecorderAndPlayer.turnOnHidingOfMorphsGeometryInfoInLabels()), (-> window.world.systemTestsRecorderAndPlayer.turnOffHidingOfMorphsGeometryInfoInLabels())

    @addOnOffSwitchLink "hide Morph content extract in labels", "-", "-", (-> window.world.systemTestsRecorderAndPlayer.turnOnHidingOfMorphsContentExtractInLabels()), (-> window.world.systemTestsRecorderAndPlayer.turnOffHidingOfMorphsContentExtractInLabels())

    @addOnOffSwitchLink "hide Morph number ID in labels", "-", "-", (-> window.world.systemTestsRecorderAndPlayer.turnOnHidingOfMorphsNumberIDInLabels()), (-> window.world.systemTestsRecorderAndPlayer.turnOffHidingOfMorphsNumberIDInLabels())

    @addLink "alt+c: take screenshot", (-> window.world.systemTestsRecorderAndPlayer.takeScreenshot())
    @addLink "alt+k: check number of items in menu", (-> window.world.systemTestsRecorderAndPlayer.checkNumberOfItemsInMenu())
    @addLink "alt+a: check menu entries (in order)", (-> window.world.systemTestsRecorderAndPlayer.checkStringsOfItemsInMenuOrderImportant())
    @addLink "alt+z: check menu entries (any order)", (-> window.world.systemTestsRecorderAndPlayer.checkStringsOfItemsInMenuOrderUnimportant())
    @addLink "alt+m: add test comment", (-> window.world.systemTestsRecorderAndPlayer.addTestComment())
    @addLink "alt+t: stop test recording", (-> window.world.systemTestsRecorderAndPlayer.stopTestRecording())
    



    
  '''

# Holds image data and metadata.
# These images are saved as javascript files
# and are used to test the actual rendering
# on screen (or parts of it)

# REQUIRES HashCalculator

class SystemTestsReferenceImage
  imageName: ''
  # the image data as string, like
  # e.g. "data:image/png;base64,iVBORw0KGgoAA..."
  imageData: ''
  systemInfo: null
  hashOfData: 0
  hashOfSystemInfo: 0
  fileName = ''

  constructor: (@imageName, @imageData, @systemInfo) ->
    @hashOfData = HashCalculator.calculateHash(@imageData)
    @hashOfSystemInfo = HashCalculator.calculateHash(JSON.stringify(@systemInfo))

    # The filenames contain the test name and the image "number"
    # AND hashes of data and metadata. This is because the same
    # test/step might have different images for different
    # OSs/browsers, so they all must be different files.
    # The js files contain directly the code to load the image.
    # There can be multiple files for the same image, since
    # the images vary according to OS and Browser, so for
    # each image of each test there is an array of files.
    # No extension added, cause we are going to
    # generate both png and js files.
    @fileName = @imageName + "-systemInfoHash" + @hashOfSystemInfo + "-dataHash" + @hashOfData

  createJSContent: ->
  	  return "if (!SystemTestsRecorderAndPlayer.loadedImages.hasOwnProperty('" + @imageName + "')) { " + "SystemTestsRecorderAndPlayer.loadedImages." + @imageName + ' = []; } ' + "SystemTestsRecorderAndPlayer.loadedImages." + @imageName + '.push(' + JSON.stringify(@) + ');'

  addToZipAsJS: (zip) ->
  	zip.file(
  	  @fileName + ".js",
  	  @createJSContent()
  	)

  # This method does the same of the one above
  # but it eliminates the "obtained-" text everywhere
  # in the content. In this way, the file can just
  # be renamed and can be added to the tests together
  # with all the other "good screenshots"
  # right away withouth having to open it and doing
  # the change manually.
  addToZipAsJSIgnoringItsAnObtained: (zip) ->
  	zip.file(
  	  @fileName + ".js",
  	  @createJSContent().replace(/obtained-/g,"")
  	)

  addToZipAsPNG: (zip) ->
    # the imageData string contains a little bit of string
    # that we need to strip out before the base64-encoded png data
    zip.file(
      @fileName + ".png",
      @imageData.replace(/^data:image\/png;base64,/, ""), {base64: true}
    )

  @coffeeScriptSourceOfThisClass: '''
# Holds image data and metadata.
# These images are saved as javascript files
# and are used to test the actual rendering
# on screen (or parts of it)

# REQUIRES HashCalculator

class SystemTestsReferenceImage
  imageName: ''
  # the image data as string, like
  # e.g. "data:image/png;base64,iVBORw0KGgoAA..."
  imageData: ''
  systemInfo: null
  hashOfData: 0
  hashOfSystemInfo: 0
  fileName = ''

  constructor: (@imageName, @imageData, @systemInfo) ->
    @hashOfData = HashCalculator.calculateHash(@imageData)
    @hashOfSystemInfo = HashCalculator.calculateHash(JSON.stringify(@systemInfo))

    # The filenames contain the test name and the image "number"
    # AND hashes of data and metadata. This is because the same
    # test/step might have different images for different
    # OSs/browsers, so they all must be different files.
    # The js files contain directly the code to load the image.
    # There can be multiple files for the same image, since
    # the images vary according to OS and Browser, so for
    # each image of each test there is an array of files.
    # No extension added, cause we are going to
    # generate both png and js files.
    @fileName = @imageName + "-systemInfoHash" + @hashOfSystemInfo + "-dataHash" + @hashOfData

  createJSContent: ->
  	  return "if (!SystemTestsRecorderAndPlayer.loadedImages.hasOwnProperty('" + @imageName + "')) { " + "SystemTestsRecorderAndPlayer.loadedImages." + @imageName + ' = []; } ' + "SystemTestsRecorderAndPlayer.loadedImages." + @imageName + '.push(' + JSON.stringify(@) + ');'

  addToZipAsJS: (zip) ->
  	zip.file(
  	  @fileName + ".js",
  	  @createJSContent()
  	)

  # This method does the same of the one above
  # but it eliminates the "obtained-" text everywhere
  # in the content. In this way, the file can just
  # be renamed and can be added to the tests together
  # with all the other "good screenshots"
  # right away withouth having to open it and doing
  # the change manually.
  addToZipAsJSIgnoringItsAnObtained: (zip) ->
  	zip.file(
  	  @fileName + ".js",
  	  @createJSContent().replace(/obtained-/g,"")
  	)

  addToZipAsPNG: (zip) ->
    # the imageData string contains a little bit of string
    # that we need to strip out before the base64-encoded png data
    zip.file(
      @fileName + ".png",
      @imageData.replace(/^data:image\/png;base64,/, ""), {base64: true}
    )
  '''

# Holds information about browser and machine
# Note that some of these could
# change during user session.

class SystemTestsSystemInfo extends SystemInfo
  # cannot just initialise the numbers here
  # cause we are going to make a JSON
  # out of this and these would not
  # be picked up.
  SystemTestsHarnessVersionMajor: null
  SystemTestsHarnessVersionMinor: null
  SystemTestsHarnessVersionRelease: null

  constructor: ->
    super()
    @SystemTestsHarnessVersionMajor = 0
    @SystemTestsHarnessVersionMinor = 1
    @SystemTestsHarnessVersionRelease = 0

  @coffeeScriptSourceOfThisClass: '''
# Holds information about browser and machine
# Note that some of these could
# change during user session.

class SystemTestsSystemInfo extends SystemInfo
  # cannot just initialise the numbers here
  # cause we are going to make a JSON
  # out of this and these would not
  # be picked up.
  SystemTestsHarnessVersionMajor: null
  SystemTestsHarnessVersionMinor: null
  SystemTestsHarnessVersionRelease: null

  constructor: ->
    super()
    @SystemTestsHarnessVersionMajor = 0
    @SystemTestsHarnessVersionMinor = 1
    @SystemTestsHarnessVersionRelease = 0
  '''

# REQUIRES SystemTestsReferenceImage
# REQUIRES SystemTestsSystemInfo

# How to load/play a test:
# from the Chrome console (Option-Command-J) OR Safari console (Option-Command-C):
# window.world.systemTestsRecorderAndPlayer.testCommandsSequence = NAMEOFTHETEST.testCommandsSequence
# (e.g. window.world.systemTestsRecorderAndPlayer.testCommandsSequence = SystemTest_attachRectangleToPartsOfInspector.testCommandsSequence )
# window.world.systemTestsRecorderAndPlayer.startTestPlaying()

# How to inspect the screenshot differences:
# after having playes a test with some failing screenshots
# comparisons:
# from the Chrome console (Option-Command-J) OR Safari console (Option-Command-C):
# window.world.systemTestsRecorderAndPlayer.saveFailedScreenshots()
# it will save a zip file containing three files for each failure:
# 1) the png of the obtained screenshot (different from the expected)
# 2) the .js file containing the data for the obtained screenshot
# (in case it's OK and should be added to the "good screenshots")
# 3) a .png file highlighting the differences in red.

# How to record a test:
# window.world.systemTestsRecorderAndPlayer.startTestRecording('nameOfTheTest')
# ...do the test...
# window.world.systemTestsRecorderAndPlayer.stopTestRecording()
# if you want to verify the test on the spot:
# window.world.systemTestsRecorderAndPlayer.startTestPlaying()

# For recording screenshot data at any time -
# can be used for screenshot comparisons during the test:
# window.world.systemTestsRecorderAndPlayer.takeScreenshot()

# How to save the test:
# window.world.systemTestsRecorderAndPlayer.saveTest()
# The created zip will contain both the test and the
# related reference images.

# What to do with the saved zip file:
# These files inside the zip package need to be added
# to the
#   ./src/tests directory
# Then the project will need to be recompiled.
# At this point the
#   ./build/indexWithTests.html
# page will automatically load all the tests and
# images. See "how to load/play a test" above
# to read how to load and play a test.

class SystemTestsRecorderAndPlayer
  testCommandsSequence: []
  @RECORDING: 0
  @PLAYING: 1
  @IDLE: 2
  @state: 2
  playingAllSystemTests: false
  indexOfSystemTestBeingPlayed: 0
  timeOfPreviouslyRecordedCommand: null
  handMorph: null
  worldMorph: null
  collectedImages: [] # array of SystemTestsReferenceImage
  collectedFailureImages: [] # array of SystemTestsReferenceImage
  testName: ''
  testDescription: 'no description'
  @loadedImages: {}
  ongoingTestPlayingTask: null
  timeOfPreviouslyPlayedCommand: 0
  indexOfTestCommandBeingPlayedFromSequence: 0

  @animationsPacingControl: false
  @alignmentOfMorphIDsMechanism: false
  @hidingOfMorphsGeometryInfoInLabels: false
  @hidingOfMorphsNumberIDInLabels: false
  @hidingOfMorphsContentExtractInLabels: false

  # this is a special place where the
  # "take pic" command places the image
  # data of a morph.
  # the test player will wait for this data
  # before doing the comparison.
  imageDataOfAParticularMorph: null
  lastMouseDownCommand: null
  lastMouseUpCommand: null


  constructor: (@worldMorph, @handMorph) ->

  # clear any test with the same name
  # that might be loaded
  # and all the images related to it
  clearAnyDataRelatedToTest: (testName) ->
    # we assume that no-one is going to
    # write a tests with more than
    # 100 reference images/screenshots
    for imageNumber in [0...100]
      # each of these is an array that could contain
      # multiple screenshots for different browser/os
      # configuration, we are clearing the variable
      # containing the array
      console.log "deleting SystemTest_#{@testName}_image_#{imageNumber}"
      delete SystemTestsRecorderAndPlayer.loadedImages["SystemTest_#{@testName}_image_#{imageNumber}"]
    console.log "deleting SystemTest_#{@testName}"
    delete window["SystemTest_#{@testName}"]
  
  startTestRecording: (@testName, @testDescription) ->

    # if test name not provided, then
    # prompt the user for it
    if not @testName?
      @testName = prompt("Please enter a test name", "test1")
    if not @testDescription?
      @testDescription = prompt("Please enter a test description", "no description")

    # if you choose the same name
    # of a previously loaded tests,
    # confusing things might happen such
    # as comparison with loaded screenshots
    # so we want to clear the data related
    # to the chosen name
    @clearAnyDataRelatedToTest @testName

    @testCommandsSequence = []
    @timeOfPreviouslyRecordedCommand = new Date().getTime()
    SystemTestsRecorderAndPlayer.state = SystemTestsRecorderAndPlayer.RECORDING

  stopTestRecording: ->
    SystemTestsRecorderAndPlayer.state = SystemTestsRecorderAndPlayer.IDLE


  # gonna use this in a callback so need
  # to make this one a double-arrow
  stopTestPlaying: ->
    console.log "wrapping up the playing of the test"
    SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole "test complete"
    SystemTestsRecorderAndPlayer.state = SystemTestsRecorderAndPlayer.IDLE
    
    # There is a background interval that polls
    # to check whether it's time/condition to play
    # the next queued command. Remove it.
    indexOfTask = @worldMorph.otherTasksToBeRunOnStep.indexOf(@ongoingTestPlayingTask)
    @worldMorph.otherTasksToBeRunOnStep.splice(indexOfTask, 1)
    @worldMorph.initEventListeners()
    
    @indexOfTestCommandBeingPlayedFromSequence = 0

    if @playingAllSystemTests
      @runNextSystemTest()

  showTestSource: ->
    window.open("data:text/text;charset=utf-8," + encodeURIComponent(JSON.stringify( @testCommandsSequence, null, 4 )))

  turnOnAnimationsPacingControl: ->
    @constructor.animationsPacingControl = true
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOnAnimationsPacingControl @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOffAnimationsPacingControl: ->
    @constructor.animationsPacingControl = false
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOffAnimationsPacingControl @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOnAlignmentOfMorphIDsMechanism: ->
    @constructor.alignmentOfMorphIDsMechanism = true
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOnAlignmentOfMorphIDsMechanism @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOffAlignmentOfMorphIDsMechanism: ->
    @constructor.alignmentOfMorphIDsMechanism = false
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOffAlignmentOfMorphIDsMechanism @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOnHidingOfMorphsGeometryInfoInLabels: ->
    @constructor.hidingOfMorphsGeometryInfoInLabels = true
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOnHidingOfMorphsGeometryInfoInLabels @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOffHidingOfMorphsGeometryInfoInLabels: ->
    @constructor.hidingOfMorphsGeometryInfoInLabels = false
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOffHidingOfMorphsGeometryInfoInLabels @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOnHidingOfMorphsContentExtractInLabels: ->
    @constructor.hidingOfMorphsContentExtractInLabels = true
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOnHidingOfMorphsContentExtractInLabels @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOffHidingOfMorphsContentExtractInLabels: ->
    @constructor.hidingOfMorphsContentExtractInLabels = false
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOffHidingOfMorphsContentExtractInLabels @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOnHidingOfMorphsNumberIDInLabels: ->
    @constructor.hidingOfMorphsNumberIDInLabels = true
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOnHidingOfMorphsNumberIDInLabels @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOffHidingOfMorphsNumberIDInLabels: ->
    @constructor.hidingOfMorphsNumberIDInLabels = false
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOffHidingOfMorphsNumberIDInLabels @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()


  addMouseMoveCommand: (pageX, pageY) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandMouseMove pageX, pageY, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addMouseDownCommand: (button, ctrlKey) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandMouseDown button, ctrlKey, @
    @lastMouseDownCommand = systemTestCommand
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addOpenContextMenuCommand: (context) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    @removeLastMouseUpAndMouseDownCommands()
    systemTestCommand = new SystemTestsCommandOpenContextMenu context, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addCommandLeftOrRightClickOnMenuItem: (mouseButton, labelString, occurrenceNumber) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    @removeLastMouseUpAndMouseDownCommands()
    systemTestCommand = new SystemTestsCommandLeftOrRightClickOnMenuItem mouseButton, labelString, occurrenceNumber, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addMouseUpCommand: ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandMouseUp @
    @lastMouseUpCommand = systemTestCommand
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()
  
  # doesn't *actually* remove the command
  # because you do need to wait the time.
  # because for example the bubbles pop-up
  # after some time.
  # You could remove the commands and note down
  # how much was the wait on each and charge it to
  # the next command but that would be very messy.
  removeLastMouseUpAndMouseDownCommands: ->
    @lastMouseDownCommand.transformIntoDoNothingCommand()
    @lastMouseUpCommand.transformIntoDoNothingCommand()

  addKeyPressCommand: (charCode, symbol, shiftKey, ctrlKey, altKey, metaKey) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandKeyPress charCode, symbol, shiftKey, ctrlKey, altKey, metaKey, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addKeyDownCommand: (scanCode, shiftKey, ctrlKey, altKey, metaKey) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandKeyDown scanCode, shiftKey, ctrlKey, altKey, metaKey, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addKeyUpCommand: (scanCode, shiftKey, ctrlKey, altKey, metaKey) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandKeyUp scanCode, shiftKey, ctrlKey, altKey, metaKey, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addCopyCommand: () ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandCopy @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addPasteCommand: (clipboardText) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandPaste clipboardText, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()


  resetWorld: ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandResetWorld @
    window[systemTestCommand.testCommandName].replayFunction @, null
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addTestComment: ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    # note how we take the time before we prompt the
    # user so we can show the message sooner when playing
    # the test - i.e. the message will appear at the time
    # the user got the prompt window rather than when she
    # actually wrote the message...
    # So we anticipate the message so the user can actually have
    # the time to read it before the test moves on with the
    # next steps.
    @timeOfPreviouslyRecordedCommand = new Date().getTime()
    comment = prompt("enter comment", "your comment here")
    systemTestCommand = new SystemTestsCommandShowComment comment, @
    @testCommandsSequence.push systemTestCommand

  checkStringsOfItemsInMenuOrderImportant: (stringOfItemsInMenuInOriginalOrder) ->
    @checkStringsOfItemsInMenu(stringOfItemsInMenuInOriginalOrder, true)

  checkStringsOfItemsInMenuOrderUnimportant: (stringOfItemsInMenuInOriginalOrder) ->
    @checkStringsOfItemsInMenu(stringOfItemsInMenuInOriginalOrder, false)

  checkStringsOfItemsInMenu: (stringOfItemsInMenuInOriginalOrder, orderMatters) ->
    console.log "checkStringsOfItemsInMenu"
    menuAtPointer = @handMorph.menuAtPointer()
    console.log menuAtPointer

    stringOfItemsInCurrentMenuInOriginalOrder = []

    if menuAtPointer?
      for eachMenuItem in menuAtPointer.items
        stringOfItemsInCurrentMenuInOriginalOrder.push eachMenuItem[0]
    else
      console.log "FAIL was expecting a menu under the pointer"
      if SystemTestsControlPanelUpdater?
        SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole errorMessage
      @stopTestPlaying()

    if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.RECORDING
      if orderMatters
        systemTestCommand = new SystemTestsCommandCheckStringsOfItemsInMenuOrderImportant stringOfItemsInCurrentMenuInOriginalOrder, @
      else
        systemTestCommand = new SystemTestsCommandCheckStringsOfItemsInMenuOrderUnimportant stringOfItemsInCurrentMenuInOriginalOrder, @

      @testCommandsSequence.push systemTestCommand
      @timeOfPreviouslyRecordedCommand = new Date().getTime()
    else if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.PLAYING
      giveSuccess = =>
        if orderMatters
          message = "PASS Strings in menu are same and in same order"
        else
          message = "PASS Strings in menu are same (not considering order)"
        if SystemTestsControlPanelUpdater?
          SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole message
      giveError = =>
        if orderMatters
          errorMessage = "FAIL Strings in menu doesn't match or order is incorrect. Was expecting: " + stringOfItemsInMenuInOriginalOrder + " found: " + stringOfItemsInCurrentMenuInOriginalOrder
        else
          errorMessage = "FAIL Strings in menu doesn't match (even not considering order). Was expecting: " + stringOfItemsInMenuInOriginalOrder + " found: " + stringOfItemsInCurrentMenuInOriginalOrder
        if SystemTestsControlPanelUpdater?
          SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole errorMessage
        @stopTestPlaying()
      
      menuListIsSame = true

      # the reason why we make a copy here is the following:
      # if you kept the original array then this could happen:
      # you record a test and then you play it back and then you save it
      # the array is always the same and could get mutated during the play
      # (because it could be sorted). So when you save the test, you
      # save the ordered array instead of the original.
      copyOfstringOfItemsInMenuInOriginalOrder = arrayShallowCopy(stringOfItemsInMenuInOriginalOrder)

      # if the order doesn't matter then we need to
      # sort the strings first so we compare regardless
      # of the original order
      if !orderMatters
        stringOfItemsInCurrentMenuInOriginalOrder.sort()
        copyOfstringOfItemsInMenuInOriginalOrder.sort()

      if stringOfItemsInCurrentMenuInOriginalOrder.length == copyOfstringOfItemsInMenuInOriginalOrder.length
        for itemNumber in [0...copyOfstringOfItemsInMenuInOriginalOrder.length]
          if copyOfstringOfItemsInMenuInOriginalOrder[itemNumber] != stringOfItemsInCurrentMenuInOriginalOrder[itemNumber]
            menuListIsSame = false
            console.log copyOfstringOfItemsInMenuInOriginalOrder[itemNumber] + " != " + stringOfItemsInCurrentMenuInOriginalOrder[itemNumber] + " at " + itemNumber
      else
        menuListIsSame = false

      if menuListIsSame
        giveSuccess()
      else
        giveError()

  checkNumberOfItemsInMenu: (numberOfItems) ->
    if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.RECORDING
      menuAtPointer = @handMorph.menuAtPointer()
      console.log menuAtPointer
      if menuAtPointer?
        numberOfItems = menuAtPointer.items.length
        console.log "found " + numberOfItems + " number of items "
      else
        console.log "was expecting a menu under the pointer"
        numberOfItems = 0
      systemTestCommand = new SystemTestsCommandCheckNumberOfItemsInMenu numberOfItems, @
      @testCommandsSequence.push systemTestCommand
      @timeOfPreviouslyRecordedCommand = new Date().getTime()
    else if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.PLAYING
      menuAtPointer = @handMorph.menuAtPointer()
      giveSuccess = =>
        message = "PASS Number of items in menu matches. Note that count includes line separators. Found: " + menuAtPointer.items.length
        if SystemTestsControlPanelUpdater?
          SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole message
      giveError = =>
        errorMessage = "FAIL Number of items in menu doesn't match. Note that count includes line separators. Was expecting: " + numberOfItems + " found: " + menuAtPointer.items.length
        if SystemTestsControlPanelUpdater?
          SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole errorMessage
        @stopTestPlaying()
      if menuAtPointer?
        if numberOfItems != menuAtPointer.items.length
          giveError()
        else
          giveSuccess()
      else
          giveError()

  takeScreenshot: (whichMorph = @worldMorph) ->
    console.log "taking screenshot"
    imageName = "SystemTest_"+@testName+"_image_" + (@collectedImages.length + 1)
    systemTestCommand = new SystemTestsCommandScreenshot imageName, @, whichMorph != @worldMorph

    # the way we take a picture here is different
    # than the way we usually take a picture.
    # Usually we ask the morph and submorphs to
    # paint themselves anew into a new canvas.
    # This is different: we take the area of the
    # screen *as it is* and we crop the part of
    # interest where the extent of our selected
    # morph is. This means that the morph might
    # be occluded by other things.
    # The advantage here is that we capture
    # the screen absolutely as is, without
    # causing any repaints. If streaks are on the
    # screen due to bad painting, we capture them
    # exactly as the user sees them.
    if whichMorph == @worldMorph
      imageData = world.worldCanvas.toDataURL("image/png")
    else
      # you can take the sceen copy for a single Morph
      # only while recording (or playing) a test by
      # choosing the "take pic" action... which otherwise
      # would usually open a new tab with the picture
      # of the "painted" morph (not sceen-copied, see
      # explanation of the differene here above)
      fullExtentOfMorph = whichMorph.boundsIncludingChildren()
      destCanvas = newCanvas fullExtentOfMorph.extent().scaleBy pixelRatio
      destCtx = destCanvas.getContext '2d'
      destCtx.drawImage world.worldCanvas,
        fullExtentOfMorph.topLeft().x * pixelRatio,
        fullExtentOfMorph.topLeft().y * pixelRatio,
        fullExtentOfMorph.width() * pixelRatio,
        fullExtentOfMorph.height() * pixelRatio,
        0,
        0,
        fullExtentOfMorph.width() * pixelRatio,
        fullExtentOfMorph.height() * pixelRatio,

      imageData = destCanvas.toDataURL "image/png"

    takenScreenshot = new SystemTestsReferenceImage(imageName,imageData, new SystemTestsSystemInfo())
    unless SystemTestsRecorderAndPlayer.loadedImages["#{imageName}"]?
      SystemTestsRecorderAndPlayer.loadedImages["#{imageName}"] = []
    SystemTestsRecorderAndPlayer.loadedImages["#{imageName}"].push takenScreenshot
    @collectedImages.push takenScreenshot
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
      return systemTestCommand

  # a lenghty method because there
  # is a lot of API dancing, but the
  # concept is really easy: return
  # a new canvas with an image that is
  # red in all areas where the
  # "expected" and "obtained" images
  # are different.
  # So it neatly highlights where the differences
  # are.
  subtractScreenshots: (expected, obtained, andThen) ->
    console.log "subtractScreenshots"
    expectedCanvas = document.createElement "canvas"
    expectedImage = new Image
    # unfortunately the operation of loading
    # the base64 data into the image is asynchronous
    # (seems to work immediately in Chrome but it's
    # recommended to consider it asynchronous)
    # so here we need to chain two callbacks
    # to make it all work, as we need to load
    # two such images.
    expectedImage.onload = =>
      console.log "expectedCanvas.imageData: " + expectedCanvas.imageData
      expectedCanvas.width = expectedImage.width
      expectedCanvas.height = expectedImage.height
      expectedCanvasContext = expectedCanvas.getContext "2d"
      console.log "expectedCanvas.width: " + expectedCanvas.width
      console.log "expectedCanvas.height: " + expectedCanvas.height
      expectedCanvasContext.drawImage(expectedImage,0,0)
      expectedImageData = expectedCanvasContext.getImageData(0, 0, expectedCanvas.width, expectedCanvas.height)

      obtainedCanvas = document.createElement "canvas"
      obtainedImage = new Image
      obtainedImage.onload = =>
        obtainedCanvas.width = obtainedImage.width
        obtainedCanvas.height = obtainedImage.height
        obtainedCanvasContext = obtainedCanvas.getContext "2d"
        obtainedCanvasContext.drawImage(obtainedImage,0,0)
        obtainedImageData = obtainedCanvasContext.getImageData(0, 0, obtainedCanvas.width, obtainedCanvas.height)

        subtractionCanvas = document.createElement "canvas"
        subtractionCanvas.width = obtainedImage.width
        subtractionCanvas.height = obtainedImage.height
        subtractionCanvasContext = subtractionCanvas.getContext("2d")
        subtractionCanvasContext.drawImage(obtainedImage,0,0)
        subtractionImageData = subtractionCanvasContext.getImageData(0, 0, subtractionCanvas.width, subtractionCanvas.height)

        i = 0
        equalPixels = 0
        differentPixels = 0

        while i < subtractionImageData.data.length
          if obtainedImageData.data[i] != expectedImageData.data[i] or
             obtainedImageData.data[i+1] != expectedImageData.data[i+1] or
             obtainedImageData.data[i+2] != expectedImageData.data[i+2]
            subtractionImageData.data[i] = 255
            subtractionImageData.data[i+1] = 0
            subtractionImageData.data[i+2] = 0
            differentPixels++
          else
            equalPixels++
          i += 4
        console.log "equalPixels: " + equalPixels
        console.log "differentPixels: " + differentPixels
        subtractionCanvasContext.putImageData subtractionImageData, 0, 0
        andThen subtractionCanvas, expected

      obtainedImage.src = obtained.imageData

    expectedImage.src = expected.imageData

  compareScreenshots: (testNameWithImageNumber, screenshotTakenOfAParticularMorph = false) ->
   if screenshotTakenOfAParticularMorph
     console.log "comparing pic of a particular morph"
     screenshotObtained = @imageDataOfAParticularMorph
     @imageDataOfAParticularMorph = null
   else
     console.log "comparing pic of whole desktop"
     screenshotObtained = @worldMorph.fullImageData()
   
   console.log "trying to match screenshot: " + testNameWithImageNumber
   console.log "length of obtained: " + screenshotObtained.length

   # There can be multiple files for the same image, since
   # the images vary according to OS and Browser, so for
   # each image of each test there is an array of candidates
   # to be checked. If any of them mathes in terms of pixel data,
   # then fine, otherwise complain...
   for eachImage in SystemTestsRecorderAndPlayer.loadedImages["#{testNameWithImageNumber}"]
     console.log "length of obtained: " + eachImage.imageData.length
     if eachImage.imageData == screenshotObtained
      message = "PASS - screenshot " + eachImage.fileName + " matched"
      console.log message
      if SystemTestsControlPanelUpdater?
        SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole message
      return
   # OK none of the images we loaded matches the one we
   # just takes. Hence create a SystemTestsReferenceImage
   # that we can let the user download - it will contain
   # the image actually obtained (rather than the one
   # we should have seen)
   message = "FAIL - no screenshots like this one"
   console.log message
   if SystemTestsControlPanelUpdater?
     SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole message
   obtainedImageName = "obtained-" + eachImage.imageName
   obtainedImage = new SystemTestsReferenceImage(obtainedImageName,screenshotObtained, new SystemTestsSystemInfo())
   @collectedFailureImages.push obtainedImage

  replayTestCommands: ->
   timeNow = (new Date()).getTime()
   commandToBePlayed = @testCommandsSequence[@indexOfTestCommandBeingPlayedFromSequence]
   # console.log "examining command: " + commandToBePlayed.testCommandName + " at: " + commandToBePlayed.millisecondsSincePreviousCommand +
   #   " time now: " + timeNow + " we are at: " + (timeNow - @timeOfPreviouslyPlayedCommand)
   timeUntilNextCommand = commandToBePlayed.millisecondsSincePreviousCommand or 0
   # for the screenshot, the replay is going
   # to consist in comparing the image data.
   # in case the screenshot is made of the entire world
   # then the comparison can happen now.
   # in case the screenshot is made of a particular
   # morph then we want to wait that the world
   # has taken that screenshot image data and put
   # it in here.
   # search for imageDataOfAParticularMorph everywhere
   # to see where the image data is created and
   # put there.
   if commandToBePlayed.testCommandName == "SystemTestsCommandScreenshot" and commandToBePlayed.screenshotTakenOfAParticularMorph
     if not @imageDataOfAParticularMorph?
       # no image data of morph, so just wait
       return
   if timeNow - @timeOfPreviouslyPlayedCommand >= timeUntilNextCommand
     console.log "running command: " + commandToBePlayed.testCommandName + " " + @indexOfTestCommandBeingPlayedFromSequence + " / " + @testCommandsSequence.length
     window[commandToBePlayed.testCommandName].replayFunction.call @,@,commandToBePlayed
     @timeOfPreviouslyPlayedCommand = timeNow
     @indexOfTestCommandBeingPlayedFromSequence++
     if @indexOfTestCommandBeingPlayedFromSequence == @testCommandsSequence.length
       console.log "stopping the test player"
       @stopTestPlaying()

  startTestPlaying: ->
    SystemTestsRecorderAndPlayer.state = SystemTestsRecorderAndPlayer.PLAYING
    @constructor.animationsPacingControl = true
    @worldMorph.removeEventListeners()
    @ongoingTestPlayingTask = (=> @replayTestCommands())
    @worldMorph.otherTasksToBeRunOnStep.push @ongoingTestPlayingTask


  testFileContentCreator: (commands) ->
    # these here below is just one string
    # spanning multiple lines, which
    # includes the testName and commands
    # in the right places.

    testToBeSerialised = {}
    testToBeSerialised.timeRecorded = new Date()
    testToBeSerialised.description = @testDescription
    # A string that can be used to group
    # tests together, imagine for example they
    # could be visualised in a tree structure of
    # some sort.
    # to begin with, it will be sorted
    # alphabetically so at the top we put the
    # "topical" tests that we just want run
    # quickly cause they are about stuff
    # we are working on right now.
    testToBeSerialised.testGroup = "00: current tests / 00: unused / 00: unused"
    testToBeSerialised.systemInfo = new SystemTestsSystemInfo()
    testToBeSerialised.testCommandsSequence = commands

    """
  // This system test is automatically
  // created.
  // This test (and related reference images)
  // can be copied in the /src/tests folder
  // to make them available in the testing
  // environment.
  var SystemTest_#{@testName};

  SystemTest_#{@testName} = #{JSON.stringify(testToBeSerialised, null, 4)};
    """

  saveFailedScreenshots: ->
    zip = new JSZip()
    
    # debugger
    # save all the images, each as a .png and .js file
    # the png is for quick browsing, while the js contains
    # the pixel data and the metadata of which configuration
    # the picture was recorded with.
    # (we expect the screenshots to be different across
    # browsers and OSs)
    # Note that the .js files are saved so the content
    # doesn't contain "obtained-" anywhere in metadata
    # (as it should, in theory) so that, if the
    # screenshot is good, the file can just be
    # renamed and moved together with the "good"
    # screenshots.
    for image in @collectedFailureImages
      image.addToZipAsJSIgnoringItsAnObtained zip
      
      # let's also save the png file so it's easier to browse the data
      # note that these png files are not copied over into the
      # build directory.
      image.addToZipAsPNG zip

    # create and save all diff .png images
    # the diff images just highlight in red
    # the parts that differ from any one
    # of the "good" screenshots
    # (remember, there can be more than one
    # good screenshot, we pick the first one
    # we find)
    for i in [0...@collectedFailureImages.length]
      failedImage = @collectedFailureImages[i]
      aGoodImageName = (failedImage).imageName.replace("obtained-", "")
      setOfGoodImages = SystemTestsRecorderAndPlayer.loadedImages[aGoodImageName]
      aGoodImage = setOfGoodImages[0]
      # note the asynchronous operation here - this is because
      # the subtractScreenshots needs to create some Images and
      # load them with data from base64 string. The operation
      # of loading the data is asynchronous...
      @subtractScreenshots failedImage, aGoodImage, (subtractionCanvas, failedImage) ->
        console.log "zipping diff file:" + "diff-"+failedImage.imageName+".png"
        zip.file("diff-"+failedImage.imageName+".png", subtractionCanvas.toDataURL().replace(/^data:image\/png;base64,/, ""), {base64: true});

    # OK the images are all put in the zip
    # asynchronously. So, in theory what we should do is to
    # check that we have all the image packed
    # and then save the zip. In practice we just wait
    # some time (200ms for each image)
    # and then save the zip.
    setTimeout \
      =>
        console.log "saving failed screenshots"
        if navigator.userAgent.search("Safari") >= 0 and navigator.userAgent.search("Chrome") < 0
          console.log "safari"
          # Safari can't save blobs nicely with a nice
          # file name, see
          # http://stuk.github.io/jszip/documentation/howto/write_zip.html
          # so what this does is it saves a file "Unknown". User
          # then has to rename it and open it.
          location.href="data:application/zip;base64," + zip.generate({type:"base64"})
        else
          console.log "not safari"
          content = zip.generate({type:"blob"})
          saveAs(content, "SystemTest_#{@testName}_failedScreenshots.zip")        
      , (@collectedFailureImages.length+1) * 200 



  saveTest: ->
    blob = @testFileContentCreator window.world.systemTestsRecorderAndPlayer.testCommandsSequence
    zip = new JSZip()
    zip.file("SystemTest_#{@testName}.js", blob);
    
    # save all the images, each as a .png and .js file
    # the png is for quick browsing, while the js contains
    # the pixel data and the metadata of which configuration
    # the picture was recorded with.
    # (we expect the screenshots to be different across
    # browsers and OSs)
    for image in @collectedImages
      image.addToZipAsJS zip
      
      # let's also save the png file so it's easier to browse the data
      # note that these png files are not copied over into the
      # build directory.
      image.addToZipAsPNG zip
    

    if navigator.userAgent.search("Safari") >= 0 and navigator.userAgent.search("Chrome") < 0
      # Safari can't save blobs nicely with a nice
      # file name, see
      # http://stuk.github.io/jszip/documentation/howto/write_zip.html
      # so what this does is it saves a file "Unknown". User
      # then has to rename it and open it.
      console.log "safari"
      location.href="data:application/zip;base64," + zip.generate({type:"base64"})
    else
      console.log "not safari"
      content = zip.generate({type:"blob"})
      saveAs(content, "SystemTest_#{@testName}.zip")    

  testsList: ->
    # Check which objects have the right name start
    console.log Object.keys(window)
    (Object.keys(window)).filter (i) ->
      console.log i.indexOf("SystemTest_")
      i.indexOf("SystemTest_") == 0

  runNextSystemTest: ->
    @indexOfSystemTestBeingPlayed++
    if @indexOfSystemTestBeingPlayed >= @testsList().length
      SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole "finished all tests"
      return
    SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole "playing test: " + @testsList()[@indexOfSystemTestBeingPlayed]
    @testCommandsSequence = window[@testsList()[@indexOfSystemTestBeingPlayed]].testCommandsSequence
    @startTestPlaying()

  runAllSystemTests: ->
    console.log "System tests: " + @testsList()
    @playingAllSystemTests = true
    @indexOfSystemTestBeingPlayed = -1
    @runNextSystemTest()

  @coffeeScriptSourceOfThisClass: '''
# REQUIRES SystemTestsReferenceImage
# REQUIRES SystemTestsSystemInfo

# How to load/play a test:
# from the Chrome console (Option-Command-J) OR Safari console (Option-Command-C):
# window.world.systemTestsRecorderAndPlayer.testCommandsSequence = NAMEOFTHETEST.testCommandsSequence
# (e.g. window.world.systemTestsRecorderAndPlayer.testCommandsSequence = SystemTest_attachRectangleToPartsOfInspector.testCommandsSequence )
# window.world.systemTestsRecorderAndPlayer.startTestPlaying()

# How to inspect the screenshot differences:
# after having playes a test with some failing screenshots
# comparisons:
# from the Chrome console (Option-Command-J) OR Safari console (Option-Command-C):
# window.world.systemTestsRecorderAndPlayer.saveFailedScreenshots()
# it will save a zip file containing three files for each failure:
# 1) the png of the obtained screenshot (different from the expected)
# 2) the .js file containing the data for the obtained screenshot
# (in case it's OK and should be added to the "good screenshots")
# 3) a .png file highlighting the differences in red.

# How to record a test:
# window.world.systemTestsRecorderAndPlayer.startTestRecording('nameOfTheTest')
# ...do the test...
# window.world.systemTestsRecorderAndPlayer.stopTestRecording()
# if you want to verify the test on the spot:
# window.world.systemTestsRecorderAndPlayer.startTestPlaying()

# For recording screenshot data at any time -
# can be used for screenshot comparisons during the test:
# window.world.systemTestsRecorderAndPlayer.takeScreenshot()

# How to save the test:
# window.world.systemTestsRecorderAndPlayer.saveTest()
# The created zip will contain both the test and the
# related reference images.

# What to do with the saved zip file:
# These files inside the zip package need to be added
# to the
#   ./src/tests directory
# Then the project will need to be recompiled.
# At this point the
#   ./build/indexWithTests.html
# page will automatically load all the tests and
# images. See "how to load/play a test" above
# to read how to load and play a test.

class SystemTestsRecorderAndPlayer
  testCommandsSequence: []
  @RECORDING: 0
  @PLAYING: 1
  @IDLE: 2
  @state: 2
  playingAllSystemTests: false
  indexOfSystemTestBeingPlayed: 0
  timeOfPreviouslyRecordedCommand: null
  handMorph: null
  worldMorph: null
  collectedImages: [] # array of SystemTestsReferenceImage
  collectedFailureImages: [] # array of SystemTestsReferenceImage
  testName: ''
  testDescription: 'no description'
  @loadedImages: {}
  ongoingTestPlayingTask: null
  timeOfPreviouslyPlayedCommand: 0
  indexOfTestCommandBeingPlayedFromSequence: 0

  @animationsPacingControl: false
  @alignmentOfMorphIDsMechanism: false
  @hidingOfMorphsGeometryInfoInLabels: false
  @hidingOfMorphsNumberIDInLabels: false
  @hidingOfMorphsContentExtractInLabels: false

  # this is a special place where the
  # "take pic" command places the image
  # data of a morph.
  # the test player will wait for this data
  # before doing the comparison.
  imageDataOfAParticularMorph: null
  lastMouseDownCommand: null
  lastMouseUpCommand: null


  constructor: (@worldMorph, @handMorph) ->

  # clear any test with the same name
  # that might be loaded
  # and all the images related to it
  clearAnyDataRelatedToTest: (testName) ->
    # we assume that no-one is going to
    # write a tests with more than
    # 100 reference images/screenshots
    for imageNumber in [0...100]
      # each of these is an array that could contain
      # multiple screenshots for different browser/os
      # configuration, we are clearing the variable
      # containing the array
      console.log "deleting SystemTest_#{@testName}_image_#{imageNumber}"
      delete SystemTestsRecorderAndPlayer.loadedImages["SystemTest_#{@testName}_image_#{imageNumber}"]
    console.log "deleting SystemTest_#{@testName}"
    delete window["SystemTest_#{@testName}"]
  
  startTestRecording: (@testName, @testDescription) ->

    # if test name not provided, then
    # prompt the user for it
    if not @testName?
      @testName = prompt("Please enter a test name", "test1")
    if not @testDescription?
      @testDescription = prompt("Please enter a test description", "no description")

    # if you choose the same name
    # of a previously loaded tests,
    # confusing things might happen such
    # as comparison with loaded screenshots
    # so we want to clear the data related
    # to the chosen name
    @clearAnyDataRelatedToTest @testName

    @testCommandsSequence = []
    @timeOfPreviouslyRecordedCommand = new Date().getTime()
    SystemTestsRecorderAndPlayer.state = SystemTestsRecorderAndPlayer.RECORDING

  stopTestRecording: ->
    SystemTestsRecorderAndPlayer.state = SystemTestsRecorderAndPlayer.IDLE


  # gonna use this in a callback so need
  # to make this one a double-arrow
  stopTestPlaying: ->
    console.log "wrapping up the playing of the test"
    SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole "test complete"
    SystemTestsRecorderAndPlayer.state = SystemTestsRecorderAndPlayer.IDLE
    
    # There is a background interval that polls
    # to check whether it's time/condition to play
    # the next queued command. Remove it.
    indexOfTask = @worldMorph.otherTasksToBeRunOnStep.indexOf(@ongoingTestPlayingTask)
    @worldMorph.otherTasksToBeRunOnStep.splice(indexOfTask, 1)
    @worldMorph.initEventListeners()
    
    @indexOfTestCommandBeingPlayedFromSequence = 0

    if @playingAllSystemTests
      @runNextSystemTest()

  showTestSource: ->
    window.open("data:text/text;charset=utf-8," + encodeURIComponent(JSON.stringify( @testCommandsSequence, null, 4 )))

  turnOnAnimationsPacingControl: ->
    @constructor.animationsPacingControl = true
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOnAnimationsPacingControl @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOffAnimationsPacingControl: ->
    @constructor.animationsPacingControl = false
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOffAnimationsPacingControl @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOnAlignmentOfMorphIDsMechanism: ->
    @constructor.alignmentOfMorphIDsMechanism = true
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOnAlignmentOfMorphIDsMechanism @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOffAlignmentOfMorphIDsMechanism: ->
    @constructor.alignmentOfMorphIDsMechanism = false
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOffAlignmentOfMorphIDsMechanism @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOnHidingOfMorphsGeometryInfoInLabels: ->
    @constructor.hidingOfMorphsGeometryInfoInLabels = true
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOnHidingOfMorphsGeometryInfoInLabels @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOffHidingOfMorphsGeometryInfoInLabels: ->
    @constructor.hidingOfMorphsGeometryInfoInLabels = false
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOffHidingOfMorphsGeometryInfoInLabels @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOnHidingOfMorphsContentExtractInLabels: ->
    @constructor.hidingOfMorphsContentExtractInLabels = true
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOnHidingOfMorphsContentExtractInLabels @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOffHidingOfMorphsContentExtractInLabels: ->
    @constructor.hidingOfMorphsContentExtractInLabels = false
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOffHidingOfMorphsContentExtractInLabels @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOnHidingOfMorphsNumberIDInLabels: ->
    @constructor.hidingOfMorphsNumberIDInLabels = true
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOnHidingOfMorphsNumberIDInLabels @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  turnOffHidingOfMorphsNumberIDInLabels: ->
    @constructor.hidingOfMorphsNumberIDInLabels = false
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandTurnOffHidingOfMorphsNumberIDInLabels @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()


  addMouseMoveCommand: (pageX, pageY) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandMouseMove pageX, pageY, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addMouseDownCommand: (button, ctrlKey) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandMouseDown button, ctrlKey, @
    @lastMouseDownCommand = systemTestCommand
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addOpenContextMenuCommand: (context) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    @removeLastMouseUpAndMouseDownCommands()
    systemTestCommand = new SystemTestsCommandOpenContextMenu context, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addCommandLeftOrRightClickOnMenuItem: (mouseButton, labelString, occurrenceNumber) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    @removeLastMouseUpAndMouseDownCommands()
    systemTestCommand = new SystemTestsCommandLeftOrRightClickOnMenuItem mouseButton, labelString, occurrenceNumber, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addMouseUpCommand: ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandMouseUp @
    @lastMouseUpCommand = systemTestCommand
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()
  
  # doesn't *actually* remove the command
  # because you do need to wait the time.
  # because for example the bubbles pop-up
  # after some time.
  # You could remove the commands and note down
  # how much was the wait on each and charge it to
  # the next command but that would be very messy.
  removeLastMouseUpAndMouseDownCommands: ->
    @lastMouseDownCommand.transformIntoDoNothingCommand()
    @lastMouseUpCommand.transformIntoDoNothingCommand()

  addKeyPressCommand: (charCode, symbol, shiftKey, ctrlKey, altKey, metaKey) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandKeyPress charCode, symbol, shiftKey, ctrlKey, altKey, metaKey, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addKeyDownCommand: (scanCode, shiftKey, ctrlKey, altKey, metaKey) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandKeyDown scanCode, shiftKey, ctrlKey, altKey, metaKey, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addKeyUpCommand: (scanCode, shiftKey, ctrlKey, altKey, metaKey) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandKeyUp scanCode, shiftKey, ctrlKey, altKey, metaKey, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addCopyCommand: () ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandCopy @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addPasteCommand: (clipboardText) ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandPaste clipboardText, @
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()


  resetWorld: ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    systemTestCommand = new SystemTestsCommandResetWorld @
    window[systemTestCommand.testCommandName].replayFunction @, null
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()

  addTestComment: ->
    return if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
    # note how we take the time before we prompt the
    # user so we can show the message sooner when playing
    # the test - i.e. the message will appear at the time
    # the user got the prompt window rather than when she
    # actually wrote the message...
    # So we anticipate the message so the user can actually have
    # the time to read it before the test moves on with the
    # next steps.
    @timeOfPreviouslyRecordedCommand = new Date().getTime()
    comment = prompt("enter comment", "your comment here")
    systemTestCommand = new SystemTestsCommandShowComment comment, @
    @testCommandsSequence.push systemTestCommand

  checkStringsOfItemsInMenuOrderImportant: (stringOfItemsInMenuInOriginalOrder) ->
    @checkStringsOfItemsInMenu(stringOfItemsInMenuInOriginalOrder, true)

  checkStringsOfItemsInMenuOrderUnimportant: (stringOfItemsInMenuInOriginalOrder) ->
    @checkStringsOfItemsInMenu(stringOfItemsInMenuInOriginalOrder, false)

  checkStringsOfItemsInMenu: (stringOfItemsInMenuInOriginalOrder, orderMatters) ->
    console.log "checkStringsOfItemsInMenu"
    menuAtPointer = @handMorph.menuAtPointer()
    console.log menuAtPointer

    stringOfItemsInCurrentMenuInOriginalOrder = []

    if menuAtPointer?
      for eachMenuItem in menuAtPointer.items
        stringOfItemsInCurrentMenuInOriginalOrder.push eachMenuItem[0]
    else
      console.log "FAIL was expecting a menu under the pointer"
      if SystemTestsControlPanelUpdater?
        SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole errorMessage
      @stopTestPlaying()

    if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.RECORDING
      if orderMatters
        systemTestCommand = new SystemTestsCommandCheckStringsOfItemsInMenuOrderImportant stringOfItemsInCurrentMenuInOriginalOrder, @
      else
        systemTestCommand = new SystemTestsCommandCheckStringsOfItemsInMenuOrderUnimportant stringOfItemsInCurrentMenuInOriginalOrder, @

      @testCommandsSequence.push systemTestCommand
      @timeOfPreviouslyRecordedCommand = new Date().getTime()
    else if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.PLAYING
      giveSuccess = =>
        if orderMatters
          message = "PASS Strings in menu are same and in same order"
        else
          message = "PASS Strings in menu are same (not considering order)"
        if SystemTestsControlPanelUpdater?
          SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole message
      giveError = =>
        if orderMatters
          errorMessage = "FAIL Strings in menu doesn't match or order is incorrect. Was expecting: " + stringOfItemsInMenuInOriginalOrder + " found: " + stringOfItemsInCurrentMenuInOriginalOrder
        else
          errorMessage = "FAIL Strings in menu doesn't match (even not considering order). Was expecting: " + stringOfItemsInMenuInOriginalOrder + " found: " + stringOfItemsInCurrentMenuInOriginalOrder
        if SystemTestsControlPanelUpdater?
          SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole errorMessage
        @stopTestPlaying()
      
      menuListIsSame = true

      # the reason why we make a copy here is the following:
      # if you kept the original array then this could happen:
      # you record a test and then you play it back and then you save it
      # the array is always the same and could get mutated during the play
      # (because it could be sorted). So when you save the test, you
      # save the ordered array instead of the original.
      copyOfstringOfItemsInMenuInOriginalOrder = arrayShallowCopy(stringOfItemsInMenuInOriginalOrder)

      # if the order doesn't matter then we need to
      # sort the strings first so we compare regardless
      # of the original order
      if !orderMatters
        stringOfItemsInCurrentMenuInOriginalOrder.sort()
        copyOfstringOfItemsInMenuInOriginalOrder.sort()

      if stringOfItemsInCurrentMenuInOriginalOrder.length == copyOfstringOfItemsInMenuInOriginalOrder.length
        for itemNumber in [0...copyOfstringOfItemsInMenuInOriginalOrder.length]
          if copyOfstringOfItemsInMenuInOriginalOrder[itemNumber] != stringOfItemsInCurrentMenuInOriginalOrder[itemNumber]
            menuListIsSame = false
            console.log copyOfstringOfItemsInMenuInOriginalOrder[itemNumber] + " != " + stringOfItemsInCurrentMenuInOriginalOrder[itemNumber] + " at " + itemNumber
      else
        menuListIsSame = false

      if menuListIsSame
        giveSuccess()
      else
        giveError()

  checkNumberOfItemsInMenu: (numberOfItems) ->
    if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.RECORDING
      menuAtPointer = @handMorph.menuAtPointer()
      console.log menuAtPointer
      if menuAtPointer?
        numberOfItems = menuAtPointer.items.length
        console.log "found " + numberOfItems + " number of items "
      else
        console.log "was expecting a menu under the pointer"
        numberOfItems = 0
      systemTestCommand = new SystemTestsCommandCheckNumberOfItemsInMenu numberOfItems, @
      @testCommandsSequence.push systemTestCommand
      @timeOfPreviouslyRecordedCommand = new Date().getTime()
    else if SystemTestsRecorderAndPlayer.state == SystemTestsRecorderAndPlayer.PLAYING
      menuAtPointer = @handMorph.menuAtPointer()
      giveSuccess = =>
        message = "PASS Number of items in menu matches. Note that count includes line separators. Found: " + menuAtPointer.items.length
        if SystemTestsControlPanelUpdater?
          SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole message
      giveError = =>
        errorMessage = "FAIL Number of items in menu doesn't match. Note that count includes line separators. Was expecting: " + numberOfItems + " found: " + menuAtPointer.items.length
        if SystemTestsControlPanelUpdater?
          SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole errorMessage
        @stopTestPlaying()
      if menuAtPointer?
        if numberOfItems != menuAtPointer.items.length
          giveError()
        else
          giveSuccess()
      else
          giveError()

  takeScreenshot: (whichMorph = @worldMorph) ->
    console.log "taking screenshot"
    imageName = "SystemTest_"+@testName+"_image_" + (@collectedImages.length + 1)
    systemTestCommand = new SystemTestsCommandScreenshot imageName, @, whichMorph != @worldMorph

    # the way we take a picture here is different
    # than the way we usually take a picture.
    # Usually we ask the morph and submorphs to
    # paint themselves anew into a new canvas.
    # This is different: we take the area of the
    # screen *as it is* and we crop the part of
    # interest where the extent of our selected
    # morph is. This means that the morph might
    # be occluded by other things.
    # The advantage here is that we capture
    # the screen absolutely as is, without
    # causing any repaints. If streaks are on the
    # screen due to bad painting, we capture them
    # exactly as the user sees them.
    if whichMorph == @worldMorph
      imageData = world.worldCanvas.toDataURL("image/png")
    else
      # you can take the sceen copy for a single Morph
      # only while recording (or playing) a test by
      # choosing the "take pic" action... which otherwise
      # would usually open a new tab with the picture
      # of the "painted" morph (not sceen-copied, see
      # explanation of the differene here above)
      fullExtentOfMorph = whichMorph.boundsIncludingChildren()
      destCanvas = newCanvas fullExtentOfMorph.extent().scaleBy pixelRatio
      destCtx = destCanvas.getContext '2d'
      destCtx.drawImage world.worldCanvas,
        fullExtentOfMorph.topLeft().x * pixelRatio,
        fullExtentOfMorph.topLeft().y * pixelRatio,
        fullExtentOfMorph.width() * pixelRatio,
        fullExtentOfMorph.height() * pixelRatio,
        0,
        0,
        fullExtentOfMorph.width() * pixelRatio,
        fullExtentOfMorph.height() * pixelRatio,

      imageData = destCanvas.toDataURL "image/png"

    takenScreenshot = new SystemTestsReferenceImage(imageName,imageData, new SystemTestsSystemInfo())
    unless SystemTestsRecorderAndPlayer.loadedImages["#{imageName}"]?
      SystemTestsRecorderAndPlayer.loadedImages["#{imageName}"] = []
    SystemTestsRecorderAndPlayer.loadedImages["#{imageName}"].push takenScreenshot
    @collectedImages.push takenScreenshot
    @testCommandsSequence.push systemTestCommand
    @timeOfPreviouslyRecordedCommand = new Date().getTime()
    if SystemTestsRecorderAndPlayer.state != SystemTestsRecorderAndPlayer.RECORDING
      return systemTestCommand

  # a lenghty method because there
  # is a lot of API dancing, but the
  # concept is really easy: return
  # a new canvas with an image that is
  # red in all areas where the
  # "expected" and "obtained" images
  # are different.
  # So it neatly highlights where the differences
  # are.
  subtractScreenshots: (expected, obtained, andThen) ->
    console.log "subtractScreenshots"
    expectedCanvas = document.createElement "canvas"
    expectedImage = new Image
    # unfortunately the operation of loading
    # the base64 data into the image is asynchronous
    # (seems to work immediately in Chrome but it's
    # recommended to consider it asynchronous)
    # so here we need to chain two callbacks
    # to make it all work, as we need to load
    # two such images.
    expectedImage.onload = =>
      console.log "expectedCanvas.imageData: " + expectedCanvas.imageData
      expectedCanvas.width = expectedImage.width
      expectedCanvas.height = expectedImage.height
      expectedCanvasContext = expectedCanvas.getContext "2d"
      console.log "expectedCanvas.width: " + expectedCanvas.width
      console.log "expectedCanvas.height: " + expectedCanvas.height
      expectedCanvasContext.drawImage(expectedImage,0,0)
      expectedImageData = expectedCanvasContext.getImageData(0, 0, expectedCanvas.width, expectedCanvas.height)

      obtainedCanvas = document.createElement "canvas"
      obtainedImage = new Image
      obtainedImage.onload = =>
        obtainedCanvas.width = obtainedImage.width
        obtainedCanvas.height = obtainedImage.height
        obtainedCanvasContext = obtainedCanvas.getContext "2d"
        obtainedCanvasContext.drawImage(obtainedImage,0,0)
        obtainedImageData = obtainedCanvasContext.getImageData(0, 0, obtainedCanvas.width, obtainedCanvas.height)

        subtractionCanvas = document.createElement "canvas"
        subtractionCanvas.width = obtainedImage.width
        subtractionCanvas.height = obtainedImage.height
        subtractionCanvasContext = subtractionCanvas.getContext("2d")
        subtractionCanvasContext.drawImage(obtainedImage,0,0)
        subtractionImageData = subtractionCanvasContext.getImageData(0, 0, subtractionCanvas.width, subtractionCanvas.height)

        i = 0
        equalPixels = 0
        differentPixels = 0

        while i < subtractionImageData.data.length
          if obtainedImageData.data[i] != expectedImageData.data[i] or
             obtainedImageData.data[i+1] != expectedImageData.data[i+1] or
             obtainedImageData.data[i+2] != expectedImageData.data[i+2]
            subtractionImageData.data[i] = 255
            subtractionImageData.data[i+1] = 0
            subtractionImageData.data[i+2] = 0
            differentPixels++
          else
            equalPixels++
          i += 4
        console.log "equalPixels: " + equalPixels
        console.log "differentPixels: " + differentPixels
        subtractionCanvasContext.putImageData subtractionImageData, 0, 0
        andThen subtractionCanvas, expected

      obtainedImage.src = obtained.imageData

    expectedImage.src = expected.imageData

  compareScreenshots: (testNameWithImageNumber, screenshotTakenOfAParticularMorph = false) ->
   if screenshotTakenOfAParticularMorph
     console.log "comparing pic of a particular morph"
     screenshotObtained = @imageDataOfAParticularMorph
     @imageDataOfAParticularMorph = null
   else
     console.log "comparing pic of whole desktop"
     screenshotObtained = @worldMorph.fullImageData()
   
   console.log "trying to match screenshot: " + testNameWithImageNumber
   console.log "length of obtained: " + screenshotObtained.length

   # There can be multiple files for the same image, since
   # the images vary according to OS and Browser, so for
   # each image of each test there is an array of candidates
   # to be checked. If any of them mathes in terms of pixel data,
   # then fine, otherwise complain...
   for eachImage in SystemTestsRecorderAndPlayer.loadedImages["#{testNameWithImageNumber}"]
     console.log "length of obtained: " + eachImage.imageData.length
     if eachImage.imageData == screenshotObtained
      message = "PASS - screenshot " + eachImage.fileName + " matched"
      console.log message
      if SystemTestsControlPanelUpdater?
        SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole message
      return
   # OK none of the images we loaded matches the one we
   # just takes. Hence create a SystemTestsReferenceImage
   # that we can let the user download - it will contain
   # the image actually obtained (rather than the one
   # we should have seen)
   message = "FAIL - no screenshots like this one"
   console.log message
   if SystemTestsControlPanelUpdater?
     SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole message
   obtainedImageName = "obtained-" + eachImage.imageName
   obtainedImage = new SystemTestsReferenceImage(obtainedImageName,screenshotObtained, new SystemTestsSystemInfo())
   @collectedFailureImages.push obtainedImage

  replayTestCommands: ->
   timeNow = (new Date()).getTime()
   commandToBePlayed = @testCommandsSequence[@indexOfTestCommandBeingPlayedFromSequence]
   # console.log "examining command: " + commandToBePlayed.testCommandName + " at: " + commandToBePlayed.millisecondsSincePreviousCommand +
   #   " time now: " + timeNow + " we are at: " + (timeNow - @timeOfPreviouslyPlayedCommand)
   timeUntilNextCommand = commandToBePlayed.millisecondsSincePreviousCommand or 0
   # for the screenshot, the replay is going
   # to consist in comparing the image data.
   # in case the screenshot is made of the entire world
   # then the comparison can happen now.
   # in case the screenshot is made of a particular
   # morph then we want to wait that the world
   # has taken that screenshot image data and put
   # it in here.
   # search for imageDataOfAParticularMorph everywhere
   # to see where the image data is created and
   # put there.
   if commandToBePlayed.testCommandName == "SystemTestsCommandScreenshot" and commandToBePlayed.screenshotTakenOfAParticularMorph
     if not @imageDataOfAParticularMorph?
       # no image data of morph, so just wait
       return
   if timeNow - @timeOfPreviouslyPlayedCommand >= timeUntilNextCommand
     console.log "running command: " + commandToBePlayed.testCommandName + " " + @indexOfTestCommandBeingPlayedFromSequence + " / " + @testCommandsSequence.length
     window[commandToBePlayed.testCommandName].replayFunction.call @,@,commandToBePlayed
     @timeOfPreviouslyPlayedCommand = timeNow
     @indexOfTestCommandBeingPlayedFromSequence++
     if @indexOfTestCommandBeingPlayedFromSequence == @testCommandsSequence.length
       console.log "stopping the test player"
       @stopTestPlaying()

  startTestPlaying: ->
    SystemTestsRecorderAndPlayer.state = SystemTestsRecorderAndPlayer.PLAYING
    @constructor.animationsPacingControl = true
    @worldMorph.removeEventListeners()
    @ongoingTestPlayingTask = (=> @replayTestCommands())
    @worldMorph.otherTasksToBeRunOnStep.push @ongoingTestPlayingTask


  testFileContentCreator: (commands) ->
    # these here below is just one string
    # spanning multiple lines, which
    # includes the testName and commands
    # in the right places.

    testToBeSerialised = {}
    testToBeSerialised.timeRecorded = new Date()
    testToBeSerialised.description = @testDescription
    # A string that can be used to group
    # tests together, imagine for example they
    # could be visualised in a tree structure of
    # some sort.
    # to begin with, it will be sorted
    # alphabetically so at the top we put the
    # "topical" tests that we just want run
    # quickly cause they are about stuff
    # we are working on right now.
    testToBeSerialised.testGroup = "00: current tests / 00: unused / 00: unused"
    testToBeSerialised.systemInfo = new SystemTestsSystemInfo()
    testToBeSerialised.testCommandsSequence = commands

    """
  // This system test is automatically
  // created.
  // This test (and related reference images)
  // can be copied in the /src/tests folder
  // to make them available in the testing
  // environment.
  var SystemTest_#{@testName};

  SystemTest_#{@testName} = #{JSON.stringify(testToBeSerialised, null, 4)};
    """

  saveFailedScreenshots: ->
    zip = new JSZip()
    
    # debugger
    # save all the images, each as a .png and .js file
    # the png is for quick browsing, while the js contains
    # the pixel data and the metadata of which configuration
    # the picture was recorded with.
    # (we expect the screenshots to be different across
    # browsers and OSs)
    # Note that the .js files are saved so the content
    # doesn't contain "obtained-" anywhere in metadata
    # (as it should, in theory) so that, if the
    # screenshot is good, the file can just be
    # renamed and moved together with the "good"
    # screenshots.
    for image in @collectedFailureImages
      image.addToZipAsJSIgnoringItsAnObtained zip
      
      # let's also save the png file so it's easier to browse the data
      # note that these png files are not copied over into the
      # build directory.
      image.addToZipAsPNG zip

    # create and save all diff .png images
    # the diff images just highlight in red
    # the parts that differ from any one
    # of the "good" screenshots
    # (remember, there can be more than one
    # good screenshot, we pick the first one
    # we find)
    for i in [0...@collectedFailureImages.length]
      failedImage = @collectedFailureImages[i]
      aGoodImageName = (failedImage).imageName.replace("obtained-", "")
      setOfGoodImages = SystemTestsRecorderAndPlayer.loadedImages[aGoodImageName]
      aGoodImage = setOfGoodImages[0]
      # note the asynchronous operation here - this is because
      # the subtractScreenshots needs to create some Images and
      # load them with data from base64 string. The operation
      # of loading the data is asynchronous...
      @subtractScreenshots failedImage, aGoodImage, (subtractionCanvas, failedImage) ->
        console.log "zipping diff file:" + "diff-"+failedImage.imageName+".png"
        zip.file("diff-"+failedImage.imageName+".png", subtractionCanvas.toDataURL().replace(/^data:image\/png;base64,/, ""), {base64: true});

    # OK the images are all put in the zip
    # asynchronously. So, in theory what we should do is to
    # check that we have all the image packed
    # and then save the zip. In practice we just wait
    # some time (200ms for each image)
    # and then save the zip.
    setTimeout \
      =>
        console.log "saving failed screenshots"
        if navigator.userAgent.search("Safari") >= 0 and navigator.userAgent.search("Chrome") < 0
          console.log "safari"
          # Safari can't save blobs nicely with a nice
          # file name, see
          # http://stuk.github.io/jszip/documentation/howto/write_zip.html
          # so what this does is it saves a file "Unknown". User
          # then has to rename it and open it.
          location.href="data:application/zip;base64," + zip.generate({type:"base64"})
        else
          console.log "not safari"
          content = zip.generate({type:"blob"})
          saveAs(content, "SystemTest_#{@testName}_failedScreenshots.zip")        
      , (@collectedFailureImages.length+1) * 200 



  saveTest: ->
    blob = @testFileContentCreator window.world.systemTestsRecorderAndPlayer.testCommandsSequence
    zip = new JSZip()
    zip.file("SystemTest_#{@testName}.js", blob);
    
    # save all the images, each as a .png and .js file
    # the png is for quick browsing, while the js contains
    # the pixel data and the metadata of which configuration
    # the picture was recorded with.
    # (we expect the screenshots to be different across
    # browsers and OSs)
    for image in @collectedImages
      image.addToZipAsJS zip
      
      # let's also save the png file so it's easier to browse the data
      # note that these png files are not copied over into the
      # build directory.
      image.addToZipAsPNG zip
    

    if navigator.userAgent.search("Safari") >= 0 and navigator.userAgent.search("Chrome") < 0
      # Safari can't save blobs nicely with a nice
      # file name, see
      # http://stuk.github.io/jszip/documentation/howto/write_zip.html
      # so what this does is it saves a file "Unknown". User
      # then has to rename it and open it.
      console.log "safari"
      location.href="data:application/zip;base64," + zip.generate({type:"base64"})
    else
      console.log "not safari"
      content = zip.generate({type:"blob"})
      saveAs(content, "SystemTest_#{@testName}.zip")    

  testsList: ->
    # Check which objects have the right name start
    console.log Object.keys(window)
    (Object.keys(window)).filter (i) ->
      console.log i.indexOf("SystemTest_")
      i.indexOf("SystemTest_") == 0

  runNextSystemTest: ->
    @indexOfSystemTestBeingPlayed++
    if @indexOfSystemTestBeingPlayed >= @testsList().length
      SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole "finished all tests"
      return
    SystemTestsControlPanelUpdater.addMessageToSystemTestsConsole "playing test: " + @testsList()[@indexOfSystemTestBeingPlayed]
    @testCommandsSequence = window[@testsList()[@indexOfSystemTestBeingPlayed]].testCommandsSequence
    @startTestPlaying()

  runAllSystemTests: ->
    console.log "System tests: " + @testsList()
    @playingAllSystemTests = true
    @indexOfSystemTestBeingPlayed = -1
    @runNextSystemTest()
  '''

# TextMorph ///////////////////////////////////////////////////////////

# I am a multi-line, word-wrapping String

# Note that in the original Jens' Morphic.js version he
# has made this quasi-inheriting from StringMorph i.e. he is copying
# over manually the following methods like so:
#
#  TextMorph::font = StringMorph::font
#  TextMorph::edit = StringMorph::edit
#  TextMorph::selection = StringMorph::selection
#  TextMorph::selectionStartSlot = StringMorph::selectionStartSlot
#  TextMorph::clearSelection = StringMorph::clearSelection
#  TextMorph::deleteSelection = StringMorph::deleteSelection
#  TextMorph::selectAll = StringMorph::selectAll
#  TextMorph::mouseClickLeft = StringMorph::mouseClickLeft
#  TextMorph::enableSelecting = StringMorph::enableSelecting 
#  TextMorph::disableSelecting = StringMorph::disableSelecting
#  TextMorph::toggleIsDraggable = StringMorph::toggleIsDraggable
#  TextMorph::toggleWeight = StringMorph::toggleWeight
#  TextMorph::toggleItalic = StringMorph::toggleItalic
#  TextMorph::setSerif = StringMorph::setSerif
#  TextMorph::setSansSerif = StringMorph::setSansSerif
#  TextMorph::setText = StringMorph::setText
#  TextMorph::setFontSize = StringMorph::setFontSize
#  TextMorph::numericalSetters = StringMorph::numericalSetters


class TextMorph extends StringMorph

  words: []
  lines: []
  lineSlots: []
  alignment: null
  maxWidth: null
  maxLineWidth: 0
  backgroundColor: null

  #additional properties for ad-hoc evaluation:
  receiver: null

  constructor: (
    text, @fontSize = 12, @fontStyle = "sans-serif", @isBold = false,
    @isItalic = false, @alignment = "left", @maxWidth = 0, fontName, shadowOffset,
    @shadowColor = null
    ) ->

      super(text, @fontSize, @fontStyle, @isBold, @isItalic, null, shadowOffset, @shadowColor,null,fontName)
      # override inherited properites:
      @markedTextColor = new Color(255, 255, 255)
      @markedBackgoundColor = new Color(60, 60, 120)
      @text = text or ((if text is "" then text else "TextMorph"))
      @fontName = fontName or WorldMorph.preferencesAndSettings.globalFontFamily
      @shadowOffset = shadowOffset or new Point(0, 0)
      @color = new Color(0, 0, 0)
      @noticesTransparentClick = true
  
  breakTextIntoLines: ->
    paragraphs = @text.split("\n")
    canvas = newCanvas()
    context = canvas.getContext("2d")
    context.scale pixelRatio, pixelRatio
    currentLine = ""
    slot = 0
    context.font = @font()
    @maxLineWidth = 0
    @lines = []
    @lineSlots = [0]
    @words = []
    
    # put all the text in an array, word by word
    paragraphs.forEach (p) =>
      @words = @words.concat(p.split(" "))
      @words.push "\n"

    # takes the text, word by word, and re-flows
    # it according to the available width for the
    # text (if there is such limit).
    # The end result is an array of lines
    # called @lines, which contains the string for
    # each line (excluding the end of lines).
    # Also another array is created, called
    # @lineSlots, which memorises how many characters
    # of the text have been consumed up to each line
    #  example: original text: "Hello\nWorld"
    # then @lines[0] = "Hello" @lines[1] = "World"
    # and @lineSlots[0] = 6, @lineSlots[1] = 11
    # Note that this algorithm doesn't work in case
    # of single non-spaced words that are longer than
    # the allowed width.
    @words.forEach (word) =>
      if word is "\n"
        # we reached the end of the line in the
        # original text, so push the line and the
        # slots count in the arrays
        @lines.push currentLine
        @lineSlots.push slot
        @maxLineWidth = Math.max(@maxLineWidth, context.measureText(currentLine).width)
        currentLine = ""
      else
        if @maxWidth > 0
          # there is a width limit, so we need
          # to check whether we overflowed it. So create
          # a prospective line and then check its width.
          lineForOverflowTest = currentLine + word + " "
          w = context.measureText(lineForOverflowTest).width
          if w > @maxWidth
            # ok we just overflowed the available space,
            # so we need to push the old line and its
            # "slot" number to the respective arrays.
            # the new line is going to only contain the
            # word that has caused the overflow.
            @lines.push currentLine
            @lineSlots.push slot
            @maxLineWidth = Math.max(@maxLineWidth, context.measureText(currentLine).width)
            currentLine = word + " "
          else
            # no overflow happened, so just proceed as normal
            currentLine = lineForOverflowTest
        else
          currentLine = currentLine + word + " "
        slot += word.length + 1
  
  
  updateRendering: ->
    @image = newCanvas()
    context = @image.getContext("2d")
    context.font = @font()
    @breakTextIntoLines()

    # set my extent
    shadowWidth = Math.abs(@shadowOffset.x)
    shadowHeight = Math.abs(@shadowOffset.y)
    height = @lines.length * (fontHeight(@fontSize) + shadowHeight)
    if @maxWidth is 0
      @bounds = @bounds.origin.extent(new Point(@maxLineWidth + shadowWidth, height))
    else
      @bounds = @bounds.origin.extent(new Point(@maxWidth + shadowWidth, height))
    @image.width = @width() * pixelRatio
    @image.height = @height() * pixelRatio

    # changing the canvas size resets many of
    # the properties of the canvas, so we need to
    # re-initialise the font and alignments here
    context.scale pixelRatio, pixelRatio
    context.font = @font()
    context.textAlign = "left"
    context.textBaseline = "bottom"

    # fill the background, if desired
    if @backgroundColor
      context.fillStyle = @backgroundColor.toString()
      context.fillRect 0, 0, @width(), @height()
    #
    # draw the shadow, if any
    if @shadowColor
      offx = Math.max(@shadowOffset.x, 0)
      offy = Math.max(@shadowOffset.y, 0)
      #console.log 'shadow x: ' + offx + " y: " + offy
      context.fillStyle = @shadowColor.toString()
      i = 0
      for line in @lines
        width = context.measureText(line).width + shadowWidth
        if @alignment is "right"
          x = @width() - width
        else if @alignment is "center"
          x = (@width() - width) / 2
        else # 'left'
          x = 0
        y = (i + 1) * (fontHeight(@fontSize) + shadowHeight) - shadowHeight
        i++
        context.fillText line, x + offx, y + offy
    #
    # now draw the actual text
    offx = Math.abs(Math.min(@shadowOffset.x, 0))
    offy = Math.abs(Math.min(@shadowOffset.y, 0))
    #console.log 'maintext x: ' + offx + " y: " + offy
    context.fillStyle = @color.toString()
    i = 0
    for line in @lines
      width = context.measureText(line).width + shadowWidth
      if @alignment is "right"
        x = @width() - width
      else if @alignment is "center"
        x = (@width() - width) / 2
      else # 'left'
        x = 0
      y = (i + 1) * (fontHeight(@fontSize) + shadowHeight) - shadowHeight
      i++
      context.fillText line, x + offx, y + offy

    # Draw the selection. This is done by re-drawing the
    # selected text, one character at the time, just with
    # a background rectangle.
    start = Math.min(@startMark, @endMark)
    stop = Math.max(@startMark, @endMark)
    for i in [start...stop]
      p = @slotCoordinates(i).subtract(@position())
      c = @text.charAt(i)
      context.fillStyle = @markedBackgoundColor.toString()
      context.fillRect p.x, p.y, context.measureText(c).width + 1, fontHeight(@fontSize)
      context.fillStyle = @markedTextColor.toString()
      context.fillText c, p.x, p.y + fontHeight(@fontSize)
    #
    # notify my parent of layout change
    @parent.layoutChanged()  if @parent.layoutChanged  if @parent
  
  setExtent: (aPoint) ->
    @maxWidth = Math.max(aPoint.x, 0)
    @changed()
    @updateRendering()
  
  # TextMorph measuring ////

  # answer the logical position point of the given index ("slot")
  # i.e. the row and the column where a particular character is.
  slotRowAndColumn: (slot) ->
    idx = 0
    # Note that this solution scans all the characters
    # in all the rows up to the slot. This could be
    # done a lot quicker by stopping at the first row
    # such that @lineSlots[theRow] <= slot
    # You could even do a binary search if one really
    # wanted to, because the contents of @lineSlots are
    # in order, as they contain a cumulative count...
    for row in [0...@lines.length]
      idx = @lineSlots[row]
      for col in [0...@lines[row].length]
        return [row, col]  if idx is slot
        idx += 1
    [@lines.length - 1, @lines[@lines.length - 1].length - 1]
  
  # Answer the position (in pixels) of the given index ("slot")
  # where the caret should be placed.
  # This is in absolute world coordinates.
  # This function assumes that the text is left-justified.
  slotCoordinates: (slot) ->
    [slotRow, slotColumn] = @slotRowAndColumn(slot)
    context = @image.getContext("2d")
    shadowHeight = Math.abs(@shadowOffset.y)
    yOffset = slotRow * (fontHeight(@fontSize) + shadowHeight)
    xOffset = context.measureText((@lines[slotRow]).substring(0,slotColumn)).width
    x = @left() + xOffset
    y = @top() + yOffset
    new Point(x, y)
  
  # Returns the slot (index) closest to the given point
  # so the caret can be moved accordingly
  # This function assumes that the text is left-justified.
  slotAt: (aPoint) ->
    charX = 0
    row = 0
    col = 0
    shadowHeight = Math.abs(@shadowOffset.y)
    context = @image.getContext("2d")
    row += 1  while aPoint.y - @top() > ((fontHeight(@fontSize) + shadowHeight) * row)
    row = Math.max(row, 1)
    while aPoint.x - @left() > charX
      charX += context.measureText(@lines[row - 1][col]).width
      col += 1
    @lineSlots[Math.max(row - 1, 0)] + col - 1
  
  upFrom: (slot) ->
    # answer the slot above the given one
    [slotRow, slotColumn] = @slotRowAndColumn(slot)
    return slot  if slotRow < 1
    above = @lines[slotRow - 1]
    return @lineSlots[slotRow - 1] + above.length  if above.length < slotColumn - 1
    @lineSlots[slotRow - 1] + slotColumn
  
  downFrom: (slot) ->
    # answer the slot below the given one
    [slotRow, slotColumn] = @slotRowAndColumn(slot)
    return slot  if slotRow > @lines.length - 2
    below = @lines[slotRow + 1]
    return @lineSlots[slotRow + 1] + below.length  if below.length < slotColumn - 1
    @lineSlots[slotRow + 1] + slotColumn
  
  startOfLine: (slot) ->
    # answer the first slot (index) of the line for the given slot
    @lineSlots[@slotRowAndColumn(slot).y]
  
  endOfLine: (slot) ->
    # answer the slot (index) indicating the EOL for the given slot
    @startOfLine(slot) + @lines[@slotRowAndColumn(slot).y].length - 1
  
  # TextMorph menus:
  developersMenu: ->
    menu = super()
    menu.addLine()
    menu.addItem "align left", (->@setAlignmentToLeft())  if @alignment isnt "left"
    menu.addItem "align right", (->@setAlignmentToRight())  if @alignment isnt "right"
    menu.addItem "align center", (->@setAlignmentToCenter())  if @alignment isnt "center"
    menu.addItem "run contents", (->@doContents())
    menu
  
  setAlignmentToLeft: ->
    @alignment = "left"
    @updateRendering()
    @changed()
  
  setAlignmentToRight: ->
    @alignment = "right"
    @updateRendering()
    @changed()
  
  setAlignmentToCenter: ->
    @alignment = "center"
    @updateRendering()
    @changed()  
  
  # TextMorph evaluation:
  evaluationMenu: ->
    menu = @hierarchyMenu()

    if @text.length > 0
      menu.prependLine()
      menu.prependItem "select all", (->@selectAllAndEdit())

    # only show the do it / show it / inspect it entries
    # if there is actually something selected.
    if @selection().replace(/^\s\s*/, '').replace(/\s\s*$/, '') != ''
      menu.prependLine()
      menu.prependItem "inspect selection", (->@inspectSelection()), "evaluate the\nselected expression\nand inspect the result"
      menu.prependItem "show selection", (->@showSelection()), "evaluate the\nselected expression\nand show the result"
      menu.prependItem "do selection", (->@doSelection()), "evaluate the\nselected expression"
    menu

  selectAllAndEdit: ->
    @edit()
    @selectAll()
   
  # this is set by the inspector. It tells the TextMorph
  # that any following doSelection/showSelection/inspectSelection action needs to be
  # done apropos a particural obj
  setReceiver: (obj) ->
    @receiver = obj
    @customContextMenu = @evaluationMenu
  
  doSelection: ->
    @receiver.evaluateString @selection()
    @edit()

  doContents: ->
    if @receiver?
      @receiver.evaluateString @text
    else
      @evaluateString @text

  showSelection: ->
    result = @receiver.evaluateString(@selection())
    if result? then @inform result
  
  inspectSelection: ->
    # evaluateString is a pimped-up eval in
    # the Morph class.
    result = @receiver.evaluateString(@selection())
    if result? then @spawnInspector result

  @coffeeScriptSourceOfThisClass: '''
# TextMorph ///////////////////////////////////////////////////////////

# I am a multi-line, word-wrapping String

# Note that in the original Jens' Morphic.js version he
# has made this quasi-inheriting from StringMorph i.e. he is copying
# over manually the following methods like so:
#
#  TextMorph::font = StringMorph::font
#  TextMorph::edit = StringMorph::edit
#  TextMorph::selection = StringMorph::selection
#  TextMorph::selectionStartSlot = StringMorph::selectionStartSlot
#  TextMorph::clearSelection = StringMorph::clearSelection
#  TextMorph::deleteSelection = StringMorph::deleteSelection
#  TextMorph::selectAll = StringMorph::selectAll
#  TextMorph::mouseClickLeft = StringMorph::mouseClickLeft
#  TextMorph::enableSelecting = StringMorph::enableSelecting 
#  TextMorph::disableSelecting = StringMorph::disableSelecting
#  TextMorph::toggleIsDraggable = StringMorph::toggleIsDraggable
#  TextMorph::toggleWeight = StringMorph::toggleWeight
#  TextMorph::toggleItalic = StringMorph::toggleItalic
#  TextMorph::setSerif = StringMorph::setSerif
#  TextMorph::setSansSerif = StringMorph::setSansSerif
#  TextMorph::setText = StringMorph::setText
#  TextMorph::setFontSize = StringMorph::setFontSize
#  TextMorph::numericalSetters = StringMorph::numericalSetters


class TextMorph extends StringMorph

  words: []
  lines: []
  lineSlots: []
  alignment: null
  maxWidth: null
  maxLineWidth: 0
  backgroundColor: null

  #additional properties for ad-hoc evaluation:
  receiver: null

  constructor: (
    text, @fontSize = 12, @fontStyle = "sans-serif", @isBold = false,
    @isItalic = false, @alignment = "left", @maxWidth = 0, fontName, shadowOffset,
    @shadowColor = null
    ) ->

      super(text, @fontSize, @fontStyle, @isBold, @isItalic, null, shadowOffset, @shadowColor,null,fontName)
      # override inherited properites:
      @markedTextColor = new Color(255, 255, 255)
      @markedBackgoundColor = new Color(60, 60, 120)
      @text = text or ((if text is "" then text else "TextMorph"))
      @fontName = fontName or WorldMorph.preferencesAndSettings.globalFontFamily
      @shadowOffset = shadowOffset or new Point(0, 0)
      @color = new Color(0, 0, 0)
      @noticesTransparentClick = true
  
  breakTextIntoLines: ->
    paragraphs = @text.split("\n")
    canvas = newCanvas()
    context = canvas.getContext("2d")
    context.scale pixelRatio, pixelRatio
    currentLine = ""
    slot = 0
    context.font = @font()
    @maxLineWidth = 0
    @lines = []
    @lineSlots = [0]
    @words = []
    
    # put all the text in an array, word by word
    paragraphs.forEach (p) =>
      @words = @words.concat(p.split(" "))
      @words.push "\n"

    # takes the text, word by word, and re-flows
    # it according to the available width for the
    # text (if there is such limit).
    # The end result is an array of lines
    # called @lines, which contains the string for
    # each line (excluding the end of lines).
    # Also another array is created, called
    # @lineSlots, which memorises how many characters
    # of the text have been consumed up to each line
    #  example: original text: "Hello\nWorld"
    # then @lines[0] = "Hello" @lines[1] = "World"
    # and @lineSlots[0] = 6, @lineSlots[1] = 11
    # Note that this algorithm doesn't work in case
    # of single non-spaced words that are longer than
    # the allowed width.
    @words.forEach (word) =>
      if word is "\n"
        # we reached the end of the line in the
        # original text, so push the line and the
        # slots count in the arrays
        @lines.push currentLine
        @lineSlots.push slot
        @maxLineWidth = Math.max(@maxLineWidth, context.measureText(currentLine).width)
        currentLine = ""
      else
        if @maxWidth > 0
          # there is a width limit, so we need
          # to check whether we overflowed it. So create
          # a prospective line and then check its width.
          lineForOverflowTest = currentLine + word + " "
          w = context.measureText(lineForOverflowTest).width
          if w > @maxWidth
            # ok we just overflowed the available space,
            # so we need to push the old line and its
            # "slot" number to the respective arrays.
            # the new line is going to only contain the
            # word that has caused the overflow.
            @lines.push currentLine
            @lineSlots.push slot
            @maxLineWidth = Math.max(@maxLineWidth, context.measureText(currentLine).width)
            currentLine = word + " "
          else
            # no overflow happened, so just proceed as normal
            currentLine = lineForOverflowTest
        else
          currentLine = currentLine + word + " "
        slot += word.length + 1
  
  
  updateRendering: ->
    @image = newCanvas()
    context = @image.getContext("2d")
    context.font = @font()
    @breakTextIntoLines()

    # set my extent
    shadowWidth = Math.abs(@shadowOffset.x)
    shadowHeight = Math.abs(@shadowOffset.y)
    height = @lines.length * (fontHeight(@fontSize) + shadowHeight)
    if @maxWidth is 0
      @bounds = @bounds.origin.extent(new Point(@maxLineWidth + shadowWidth, height))
    else
      @bounds = @bounds.origin.extent(new Point(@maxWidth + shadowWidth, height))
    @image.width = @width() * pixelRatio
    @image.height = @height() * pixelRatio

    # changing the canvas size resets many of
    # the properties of the canvas, so we need to
    # re-initialise the font and alignments here
    context.scale pixelRatio, pixelRatio
    context.font = @font()
    context.textAlign = "left"
    context.textBaseline = "bottom"

    # fill the background, if desired
    if @backgroundColor
      context.fillStyle = @backgroundColor.toString()
      context.fillRect 0, 0, @width(), @height()
    #
    # draw the shadow, if any
    if @shadowColor
      offx = Math.max(@shadowOffset.x, 0)
      offy = Math.max(@shadowOffset.y, 0)
      #console.log 'shadow x: ' + offx + " y: " + offy
      context.fillStyle = @shadowColor.toString()
      i = 0
      for line in @lines
        width = context.measureText(line).width + shadowWidth
        if @alignment is "right"
          x = @width() - width
        else if @alignment is "center"
          x = (@width() - width) / 2
        else # 'left'
          x = 0
        y = (i + 1) * (fontHeight(@fontSize) + shadowHeight) - shadowHeight
        i++
        context.fillText line, x + offx, y + offy
    #
    # now draw the actual text
    offx = Math.abs(Math.min(@shadowOffset.x, 0))
    offy = Math.abs(Math.min(@shadowOffset.y, 0))
    #console.log 'maintext x: ' + offx + " y: " + offy
    context.fillStyle = @color.toString()
    i = 0
    for line in @lines
      width = context.measureText(line).width + shadowWidth
      if @alignment is "right"
        x = @width() - width
      else if @alignment is "center"
        x = (@width() - width) / 2
      else # 'left'
        x = 0
      y = (i + 1) * (fontHeight(@fontSize) + shadowHeight) - shadowHeight
      i++
      context.fillText line, x + offx, y + offy

    # Draw the selection. This is done by re-drawing the
    # selected text, one character at the time, just with
    # a background rectangle.
    start = Math.min(@startMark, @endMark)
    stop = Math.max(@startMark, @endMark)
    for i in [start...stop]
      p = @slotCoordinates(i).subtract(@position())
      c = @text.charAt(i)
      context.fillStyle = @markedBackgoundColor.toString()
      context.fillRect p.x, p.y, context.measureText(c).width + 1, fontHeight(@fontSize)
      context.fillStyle = @markedTextColor.toString()
      context.fillText c, p.x, p.y + fontHeight(@fontSize)
    #
    # notify my parent of layout change
    @parent.layoutChanged()  if @parent.layoutChanged  if @parent
  
  setExtent: (aPoint) ->
    @maxWidth = Math.max(aPoint.x, 0)
    @changed()
    @updateRendering()
  
  # TextMorph measuring ////

  # answer the logical position point of the given index ("slot")
  # i.e. the row and the column where a particular character is.
  slotRowAndColumn: (slot) ->
    idx = 0
    # Note that this solution scans all the characters
    # in all the rows up to the slot. This could be
    # done a lot quicker by stopping at the first row
    # such that @lineSlots[theRow] <= slot
    # You could even do a binary search if one really
    # wanted to, because the contents of @lineSlots are
    # in order, as they contain a cumulative count...
    for row in [0...@lines.length]
      idx = @lineSlots[row]
      for col in [0...@lines[row].length]
        return [row, col]  if idx is slot
        idx += 1
    [@lines.length - 1, @lines[@lines.length - 1].length - 1]
  
  # Answer the position (in pixels) of the given index ("slot")
  # where the caret should be placed.
  # This is in absolute world coordinates.
  # This function assumes that the text is left-justified.
  slotCoordinates: (slot) ->
    [slotRow, slotColumn] = @slotRowAndColumn(slot)
    context = @image.getContext("2d")
    shadowHeight = Math.abs(@shadowOffset.y)
    yOffset = slotRow * (fontHeight(@fontSize) + shadowHeight)
    xOffset = context.measureText((@lines[slotRow]).substring(0,slotColumn)).width
    x = @left() + xOffset
    y = @top() + yOffset
    new Point(x, y)
  
  # Returns the slot (index) closest to the given point
  # so the caret can be moved accordingly
  # This function assumes that the text is left-justified.
  slotAt: (aPoint) ->
    charX = 0
    row = 0
    col = 0
    shadowHeight = Math.abs(@shadowOffset.y)
    context = @image.getContext("2d")
    row += 1  while aPoint.y - @top() > ((fontHeight(@fontSize) + shadowHeight) * row)
    row = Math.max(row, 1)
    while aPoint.x - @left() > charX
      charX += context.measureText(@lines[row - 1][col]).width
      col += 1
    @lineSlots[Math.max(row - 1, 0)] + col - 1
  
  upFrom: (slot) ->
    # answer the slot above the given one
    [slotRow, slotColumn] = @slotRowAndColumn(slot)
    return slot  if slotRow < 1
    above = @lines[slotRow - 1]
    return @lineSlots[slotRow - 1] + above.length  if above.length < slotColumn - 1
    @lineSlots[slotRow - 1] + slotColumn
  
  downFrom: (slot) ->
    # answer the slot below the given one
    [slotRow, slotColumn] = @slotRowAndColumn(slot)
    return slot  if slotRow > @lines.length - 2
    below = @lines[slotRow + 1]
    return @lineSlots[slotRow + 1] + below.length  if below.length < slotColumn - 1
    @lineSlots[slotRow + 1] + slotColumn
  
  startOfLine: (slot) ->
    # answer the first slot (index) of the line for the given slot
    @lineSlots[@slotRowAndColumn(slot).y]
  
  endOfLine: (slot) ->
    # answer the slot (index) indicating the EOL for the given slot
    @startOfLine(slot) + @lines[@slotRowAndColumn(slot).y].length - 1
  
  # TextMorph menus:
  developersMenu: ->
    menu = super()
    menu.addLine()
    menu.addItem "align left", (->@setAlignmentToLeft())  if @alignment isnt "left"
    menu.addItem "align right", (->@setAlignmentToRight())  if @alignment isnt "right"
    menu.addItem "align center", (->@setAlignmentToCenter())  if @alignment isnt "center"
    menu.addItem "run contents", (->@doContents())
    menu
  
  setAlignmentToLeft: ->
    @alignment = "left"
    @updateRendering()
    @changed()
  
  setAlignmentToRight: ->
    @alignment = "right"
    @updateRendering()
    @changed()
  
  setAlignmentToCenter: ->
    @alignment = "center"
    @updateRendering()
    @changed()  
  
  # TextMorph evaluation:
  evaluationMenu: ->
    menu = @hierarchyMenu()

    if @text.length > 0
      menu.prependLine()
      menu.prependItem "select all", (->@selectAllAndEdit())

    # only show the do it / show it / inspect it entries
    # if there is actually something selected.
    if @selection().replace(/^\s\s*/, '').replace(/\s\s*$/, '') != ''
      menu.prependLine()
      menu.prependItem "inspect selection", (->@inspectSelection()), "evaluate the\nselected expression\nand inspect the result"
      menu.prependItem "show selection", (->@showSelection()), "evaluate the\nselected expression\nand show the result"
      menu.prependItem "do selection", (->@doSelection()), "evaluate the\nselected expression"
    menu

  selectAllAndEdit: ->
    @edit()
    @selectAll()
   
  # this is set by the inspector. It tells the TextMorph
  # that any following doSelection/showSelection/inspectSelection action needs to be
  # done apropos a particural obj
  setReceiver: (obj) ->
    @receiver = obj
    @customContextMenu = @evaluationMenu
  
  doSelection: ->
    @receiver.evaluateString @selection()
    @edit()

  doContents: ->
    if @receiver?
      @receiver.evaluateString @text
    else
      @evaluateString @text

  showSelection: ->
    result = @receiver.evaluateString(@selection())
    if result? then @inform result
  
  inspectSelection: ->
    # evaluateString is a pimped-up eval in
    # the Morph class.
    result = @receiver.evaluateString(@selection())
    if result? then @spawnInspector result
  '''

# WorkspaceMorph //////////////////////////////////////////////////////

# just an experiment to see how a "close" button at the top left of
# any window would look like. Unclear why I called it something
# so important given that this looks like a temporary experiment.

class WorkspaceMorph extends BoxMorph

  # panes:
  morphsList: null
  buttonClose: null
  resizer: null

  constructor: (target) ->
    super()

    @silentSetExtent new Point(
      WorldMorph.preferencesAndSettings.handleSize * 10,
      WorldMorph.preferencesAndSettings.handleSize * 20 * 2 / 3)
    @isDraggable = true
    @border = 1
    @edge = 5
    @color = new Color(60, 60, 60)
    @borderColor = new Color(95, 95, 95)
    @buildAndConnectChildren()
  
  setTarget: (target) ->
    @target = target
    @currentProperty = null
    @buildAndConnectChildren()
  
  buildAndConnectChildren: ->
    attribs = []

    # remove existing panes
    @destroyAll()

    @children = []

    # label
    @label = new TextMorph("Morphs List")
    @label.fontSize = WorldMorph.preferencesAndSettings.menuFontSize
    @label.isBold = true
    @label.color = new Color(255, 255, 255)
    @add @label

    # Check which objects end with the word Morph
    theWordMorph = "Morph"
    ListOfMorphs = (Object.keys(window)).filter (i) ->
      i.indexOf(theWordMorph, i.length - theWordMorph.length) isnt -1
    @morphsList = new ListMorph(ListOfMorphs, null)

    # so far nothing happens when items are selected
    #@morphsList.action = (selected) ->
    #  val = myself.target[selected]
    #  myself.currentProperty = val
    #  if val is null
    #    txt = "NULL"
    #  else if isString(val)
    #    txt = val
    #  else
    #    txt = val.toString()
    #  cnts = new TextMorph(txt)
    #  cnts.isEditable = true
    #  cnts.enableSelecting()
    #  cnts.setReceiver myself.target
    #  myself.detail.setContents cnts

    @morphsList.hBar.alpha = 0.6
    @morphsList.vBar.alpha = 0.6
    @add @morphsList

    # close button
    @buttonClose = new TriggerMorph(@)
    @buttonClose.setLabel "close"
    @buttonClose.action = =>
      @destroy()

    @add @buttonClose

    # resizer
    @resizer = new HandleMorph(@, 150, 100, @edge, @edge)

    # update layout
    @layoutSubmorphs()
  
  layoutSubmorphs: ->
    Morph::trackChanges = false

    handleSize = WorldMorph.preferencesAndSettings.handleSize;

    x = @left() + @edge
    y = @top() + @edge
    r = @right() - @edge
    w = r - x

    # label
    @label.setPosition new Point(x + handleSize * 2/3 + @edge, y - @edge/2)
    @label.setWidth w
    if @label.height() > (@height() - 50)
      @setHeight @label.height() + 50
      @changed()
      #@resizer.updateRendering()

    # morphsList
    y = @label.bottom() + @edge/2
    w = @width() - @edge
    w -= @edge
    b = @bottom() - (2 * @edge) - handleSize
    h = b - y
    @morphsList.setPosition new Point(x, y)
    @morphsList.setExtent new Point(w, h)

    # close button
    x = @morphsList.left()
    y = @morphsList.bottom() + @edge
    h = handleSize
    w = @morphsList.width() - h - @edge
    @buttonClose.setPosition new Point(x, y)
    @buttonClose.setExtent new Point(w, h)
    Morph::trackChanges = true
    @changed()
  
  setExtent: (aPoint) ->
    super aPoint
    @layoutSubmorphs()

  @coffeeScriptSourceOfThisClass: '''
# WorkspaceMorph //////////////////////////////////////////////////////

# just an experiment to see how a "close" button at the top left of
# any window would look like. Unclear why I called it something
# so important given that this looks like a temporary experiment.

class WorkspaceMorph extends BoxMorph

  # panes:
  morphsList: null
  buttonClose: null
  resizer: null

  constructor: (target) ->
    super()

    @silentSetExtent new Point(
      WorldMorph.preferencesAndSettings.handleSize * 10,
      WorldMorph.preferencesAndSettings.handleSize * 20 * 2 / 3)
    @isDraggable = true
    @border = 1
    @edge = 5
    @color = new Color(60, 60, 60)
    @borderColor = new Color(95, 95, 95)
    @buildAndConnectChildren()
  
  setTarget: (target) ->
    @target = target
    @currentProperty = null
    @buildAndConnectChildren()
  
  buildAndConnectChildren: ->
    attribs = []

    # remove existing panes
    @destroyAll()

    @children = []

    # label
    @label = new TextMorph("Morphs List")
    @label.fontSize = WorldMorph.preferencesAndSettings.menuFontSize
    @label.isBold = true
    @label.color = new Color(255, 255, 255)
    @add @label

    # Check which objects end with the word Morph
    theWordMorph = "Morph"
    ListOfMorphs = (Object.keys(window)).filter (i) ->
      i.indexOf(theWordMorph, i.length - theWordMorph.length) isnt -1
    @morphsList = new ListMorph(ListOfMorphs, null)

    # so far nothing happens when items are selected
    #@morphsList.action = (selected) ->
    #  val = myself.target[selected]
    #  myself.currentProperty = val
    #  if val is null
    #    txt = "NULL"
    #  else if isString(val)
    #    txt = val
    #  else
    #    txt = val.toString()
    #  cnts = new TextMorph(txt)
    #  cnts.isEditable = true
    #  cnts.enableSelecting()
    #  cnts.setReceiver myself.target
    #  myself.detail.setContents cnts

    @morphsList.hBar.alpha = 0.6
    @morphsList.vBar.alpha = 0.6
    @add @morphsList

    # close button
    @buttonClose = new TriggerMorph(@)
    @buttonClose.setLabel "close"
    @buttonClose.action = =>
      @destroy()

    @add @buttonClose

    # resizer
    @resizer = new HandleMorph(@, 150, 100, @edge, @edge)

    # update layout
    @layoutSubmorphs()
  
  layoutSubmorphs: ->
    Morph::trackChanges = false

    handleSize = WorldMorph.preferencesAndSettings.handleSize;

    x = @left() + @edge
    y = @top() + @edge
    r = @right() - @edge
    w = r - x

    # label
    @label.setPosition new Point(x + handleSize * 2/3 + @edge, y - @edge/2)
    @label.setWidth w
    if @label.height() > (@height() - 50)
      @setHeight @label.height() + 50
      @changed()
      #@resizer.updateRendering()

    # morphsList
    y = @label.bottom() + @edge/2
    w = @width() - @edge
    w -= @edge
    b = @bottom() - (2 * @edge) - handleSize
    h = b - y
    @morphsList.setPosition new Point(x, y)
    @morphsList.setExtent new Point(w, h)

    # close button
    x = @morphsList.left()
    y = @morphsList.bottom() + @edge
    h = handleSize
    w = @morphsList.width() - h - @edge
    @buttonClose.setPosition new Point(x, y)
    @buttonClose.setExtent new Point(w, h)
    Morph::trackChanges = true
    @changed()
  
  setExtent: (aPoint) ->
    super aPoint
    @layoutSubmorphs()
  '''

morphicVersion = 'version of 2015-02-21 12:18:43'