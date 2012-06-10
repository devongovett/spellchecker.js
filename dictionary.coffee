{parseFlags} = require './shared'

class Dictionary
    constructor: (@affix, data) ->
        @trie = {}
        @parse(data)
        
    parse: (data) ->
        lines = data.split '\n'
        size = lines.shift()
        
        for line in lines
            line = line.replace(/^\t.*$/g, '').trim() # ignore morphological fields and trim line
            continue if line.length is 0
            
            parts = line.split('/', 2)
            word = parts[0]
            
            if parts.length > 1
                flags = parseFlags(@affix.flags['FLAG'], parts[1])
                
            @addWord word, flags
            
        return
        
    applyRule: (word, rule) ->
        words = []

        for entry in rule.entries
            continue unless not entry.match or word.match(entry.match)

            newWord = word
            newWord = newWord.replace(entry.remove, '') if entry.remove

            if rule.type is "SFX"
                newWord += entry.add
            else
                newWord = entry.add + newWord

            words.push newWord    
            continue unless entry.continuation

            for continuation in entry.continuation
                words = words.concat @applyRule(newWord, @affix.rules[continuation])

        return words
            
    addWord: (word, codes) ->
        node = @trie
        last = word.length - 1
        
        for char, i in word
            node = node[char] ?= {}
            node.$ = codes if i is last
                
        return
        
    lookup: (word) ->
        node = @trie
        
        for char in word
            return null unless node = node[char]
        
        return node.$
        
    hasFlag: (word, flag) ->
        return false unless flag of @affix.flags
        
        flags = @lookup word
        return true if flags and @affix.flags[flag] in flags
        return false
        
module.exports = Dictionary