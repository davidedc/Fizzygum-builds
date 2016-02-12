// Generated by CoffeeScript 1.7.1
window.DoubleLinkedList_coffeSource = '## from https://github.com/viruschidai/lru-cache\n## used for LRU cache\n\nclass DoubleLinkedList\n  constructor:  ->\n    @headNode = @tailNode = null\n\n  # removes the last element. Since\n  # we move used elements to head, the last\n  # element is *probably* a relatively\n  # unused one.\n  remove: (node) ->\n    if node.pre\n      node.pre.next = node.next\n    else\n      @headNode = node.next\n\n    if node.next\n      node.next.pre = node.pre\n    else\n      @tailNode = node.pre\n\n  insertBeginning: (node) ->\n    if @headNode\n      node.next = @headNode\n      @headNode.pre = node\n      @headNode = node\n    else\n      @headNode = @tailNode = node\n\n  moveToHead: (node) ->\n    @remove node\n    @insertBeginning node\n\n  clear: ->\n    @headNode = @tailNode = null';
