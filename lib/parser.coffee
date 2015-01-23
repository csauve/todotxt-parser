_ = require "underscore"

buildPattern = (opt) ->
  # returns interpolation-friendly regex
  interp = (expr) ->
    expr().toString()[1..-2]

  DATE = -> opt.dateRegex || /\d{4}-\d{2}-\d{2}/
  START = -> if opt.relaxedWhitespace then /^\s*/ else /^/
  SPACE = -> if opt.relaxedWhitespace then /\s+/ else /\s/
  COMPLETE = -> ///
    (x)#{if opt.requireCompletionDate then interp SPACE else ""}
    (#{interp DATE})#{if opt.requireCompletionDate then "" else "?"}
  ///
  PRIORITY = -> if opt.ignorePriorityCase then /\(([A-Za-z])\)/ else /\(([A-Z])\)/

  ///
    #{interp START}
    (?:#{interp COMPLETE}#{interp SPACE})?  # completion mark and date
    (?:#{interp PRIORITY}#{interp SPACE})?  # priority
    (?:(#{interp DATE})#{interp SPACE})?    # created date
    (.*)                                    # task text (may contain +projects, @contexts, meta:data)
    $
  ///

# todo: heirarchical support
module.exports =
  parse: (s, options = {}) ->
    # the defaults adhere to Gina Trapani's vanilla/canonical todo.txt-cli format & implementation
    _.defaults options,
      dateParser: (s) -> Date.parse s
      dateRegex: null
      relaxedWhitespace: false
      requireCompletionDate: true
      ignorePriorityCase: false
      heirarchical: false
      commentRegex: null
      projectRegex: /\s\+(\S+)/g
      contextRegex: /\s@(\S+)/g
      # collection of functions that parse the task text and return key:value objects
      extensions: []

    pattern = buildPattern options

    for line in s.split "\n"
      taskMatch = line.match pattern
      commentMatch = if options.commentRegex then line.match options.commentRegex
      if !taskMatch or commentMatch then continue

      text = taskMatch[5].trim()
      projects = while match = options.projectRegex.exec text
        match[1]
      contexts = while match = options.contextRegex.exec text
        match[1]
      metadata = {}
      for dataParser in options.extensions
        data = dataParser text
        for key, value of data
          metadata[key] = value

      raw: taskMatch[0]
      text: text
      projects: projects
      contexts: contexts
      complete: taskMatch[1]?
      dateCreated: if taskMatch[4] then options.dateParser taskMatch[4] else null
      dateCompleted: if taskMatch[2] then options.dateParser taskMatch[2] else null
      priority: (taskMatch[3] || metadata.pri)?.toUpperCase() || null
      metadata: metadata

  # parsing function with default values
  canonical: (s) ->
    module.exports.parse s

  # parsing function with relaxed options
  relaxed: (s) ->
    module.exports.parse s,
      dateParser: (s) -> Date.parse s
      dateRegex: null
      relaxedWhitespace: true
      requireCompletionDate: false
      ignorePriorityCase: true
      heirarchical: false
      commentRegex: /^\s*#.*$/
      projectRegex: /(?:\s+|^)\+(\S+)/g
      contextRegex: /(?:\s+|^)@(\S+)/g
      # collection of functions that parse the task text and return key:value objects
      extensions: [
        (text) ->
          metadata = {}
          metadataRegex = /(?:\s+|^)(\S+):(\S+)/g
          while match = metadataRegex.exec text
            metadata[match[1].toLowerCase()] = match[2]
          metadata
      ]