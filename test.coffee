fs = require 'fs'
SpellChecker = require './spellchecker'

aff = fs.readFileSync('./en-us/en-us.aff', 'utf8')
dic = fs.readFileSync('./en-us/en-us.dic', 'utf8')

s = new SpellChecker(aff, dic)

console.time('suggest')
console.log s.suggest('lisence')
console.timeEnd('suggest')