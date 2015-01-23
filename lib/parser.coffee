_ = require "underscore"

# configurable regular expressions
DATE = (opt) -> opt.datePattern || /\d{4}-\d{2}-\d{2}/
START = (opt) -> if opt.relaxedWhitespace then /^\s*/ else /^/
SPACE = (opt) -> if opt.relaxedWhitespace then /\s+/ else /\s/
COMPLETE = (opt) -> ///
  (x)#{SPACE(opt)}
  #{if opt.requireCompletionDate then ///(#{DATE(opt)})/// else ///(#{DATE(opt)})?///}
///
PRIORITY = (opt) -> if opt.ignorePriorityCase then /\(([A-Za-z])\)/ else /\(([A-Z])\)/

TASK_PATTERN = (opt) -> ///
  #{START(opt)}
  (?:#{COMPLETE(opt)}#{SPACE(opt)})?  # completion mark and date
  (?:#{PRIORITY(opt)}#{SPACE(opt)})?  # priority
  (?:(#{DATE(opt)})#{SPACE(opt)})?    # created date
  (.*)                                # task text (may contain +projects, @contexts, meta:data)
///

module.exports =
  parse: (s, options) ->
    # defauts adhere to Gina Trapani's todo.txt-cli implementation (strict)
    _defaults options,
      dateParser: (s) -> Date.parse s
      datePattern: null
      relaxedWhitespace: false
      requireCompletionDate: true
      ignorePriorityCase: false
      heirarchical: false

    pattern = TASK_PATTERN options

    for line in s.split "\n"
      console.dir line.match pattern

      return {
        text: line.trim()
        projects: []
        contexts: []
        complete: false
        dateCreated: null
        dateCompleted: null
        priority: null
      }