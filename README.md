spellchecker.js
===============
A spellchecker in CoffeeScript/JavaScript based on [Hunspell](http://hunspell.sourceforge.net).

## Usage

You can use spellchecker.js in browser and Node.js/CommonJS environments.  spellchecker.js requires a hunspell style
dictionary, including the `.dic` and `.aff` files.  After reading them, you create a `SpellChecker` instance.  SpellCheckers
have two major methods: `check` and `suggest` for checking if a word is correctly spelled, and for making spelling suggestions 
for a misspelled word.  Here's an example:

```coffeescript
fs = require 'fs'
SpellChecker = require './spellchecker'

# load the dictionary files
aff = fs.readFileSync('./en-us/en-us.aff', 'utf8')
dic = fs.readFileSync('./en-us/en-us.dic', 'utf8')

# create a SpellChecker
checker = new SpellChecker(aff, dic)

# check if a word is spelled correctly
checker.check('spelling') # true
checker.check('speling')  # false

# get spelling suggestions
checker.suggest('speling') # ['spelling', 'spline']
checker.suggest('lisence') # ['silence', 'license']
```

## Performance

Performance of checking words is generally very good, and suggestions are often fast as well depending on how badly the word
is spelled.  Performance improvements are always welcome, however! :)

## Licence

spellchecker.js is released under the MIT license.