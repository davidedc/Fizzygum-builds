// Generated by CoffeeScript 1.7.1
window.LRUCache_coffeSource = '## LRU cache\n## from https://github.com/viruschidai/lru-cache\n\n# REQUIRES DoubleLinkedList\n\nclass LRUCache\n  constructor: (@capacity = 10, @maxAge = 60000) ->\n    @_linkList = new DoubleLinkedList()\n    @reset()\n\n  keys: ->\n    return Object.keys @_hash\n\n  values: ->\n    values = @keys().map (key) =>\n      @get key\n    return values.filter (v) -> v isnt undefined\n\n  remove: (key) ->\n    if @_hash[key]?\n      node = @_hash[key]\n      @_linkList.remove node\n      delete @_hash[key]\n      if node.data.onDispose then node.data.onDispose.call this, node.data.key, node.data.value\n      @size--\n\n  reset: ->\n    @_hash = {}\n    @size = 0\n    @_linkList.clear()\n\n  set: (key, value, onDispose) ->\n    node = @_hash[key]\n    if node\n      node.data.value = value\n      node.data.onDispose = onDispose\n      @_refreshNode node\n    else\n      if @size is @capacity then @remove @_linkList.tailNode.data.key\n\n      createNode = (data, pre, next) -> {data, pre, next}\n\n      node = createNode {key, value, onDispose}\n      node.data.lastVisitTime = Date.now()\n      @_linkList.insertBeginning node\n      @_hash[key] = node\n      @size++\n      return\n\n  get: (key) ->\n    node = @_hash[key]\n    if !node then return undefined\n    if @_isExpiredNode node\n      @remove key\n      return undefined\n    @_refreshNode node\n    return node.data.value\n\n  _refreshNode: (node) ->\n    node.data.lastVisitTime = Date.now()\n    @_linkList.moveToHead node\n\n  _isExpiredNode: (node) ->\n    return Date.now() - node.data.lastVisitTime > @maxAge\n\n  has: (key) -> return @_hash[key]?';
