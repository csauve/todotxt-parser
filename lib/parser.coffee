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
      inherit: false
      commentRegex: null
      projectRegex: /\s\+(\S+)/g
      contextRegex: /\s@(\S+)/g
      # collection of functions that parse the task text and return key:value objects
      extensions: []

    pattern = buildPattern options
    root =
      subtasks: []
      indentLevel: -1
      contexts: []
      projects: []
      metadata: {}
    stack = [root]

    for line in s.split "\n"
      taskMatch = line.match pattern
      commentMatch = if options.commentRegex then line.match options.commentRegex
      if !taskMatch or commentMatch then continue
      text = taskMatch[5].trim()

      indentLevel = if match = line.match /^(\s+).+/
          # if line starts with a space, then count the number of leading whitespace characters
          match[1].length
        else if match = line.match /^x(\s+).+/
          # if line starts with x, then count the whitespace after it + 1 (for the x)
          match[1].length + 1
        else 0

      # figure out where we are in the hierarchy
      prevSibling = _.last(_.last(stack).subtasks) || _.last(stack)
      if indentLevel > prevSibling.indentLevel
        stack.push prevSibling
      while indentLevel <= _.last(stack).indentLevel
        stack.pop()

      parent = _.last(stack)

      # projects
      projectsSet = {}
      if options.inherit
        projectsSet[project] = true for project in parent.projects
      while match = options.projectRegex.exec text
        projectsSet[match[1]] = true

      # contexts
      contextsSet = {}
      if options.inherit
        contextsSet[context] = true for context in parent.contexts
      while match = options.contextRegex.exec text
        contextsSet[match[1]] = true

      # metadata from extensions
      metadata = {}
      if options.inherit
        metadata[key] = value for key, value of parent.metadata
      for dataParser in options.extensions
        data = dataParser text
        for key, value of data
          metadata[key] = value

      complete = if taskMatch[1]
        true
      else if options.inherit
        parent.complete
      else false

      dateCreated = if taskMatch[4]
        options.dateParser taskMatch[4]
      else if options.inherit
        parent.dateCreated
      else null

      dateCompleted = if taskMatch[2]
        options.dateParser taskMatch[2]
      else if options.inherit
        parent.dateCompleted
      else null

      priority = (taskMatch[3] || metadata.pri)?.toUpperCase() || if options.inherit
        parent.priority
      else null

      task =
        raw: taskMatch[0]
        text: text
        projects: key for key of projectsSet
        contexts: key for key of contextsSet
        complete: complete
        dateCreated: dateCreated
        dateCompleted: dateCompleted
        priority: priority
        metadata: metadata
        subtasks: []
        indentLevel: indentLevel

      _.last(stack).subtasks.push task

    root.subtasks


  # parsing function with default values
  canonical: (s) ->
    module.exports.parse s

  # parsing function with relaxed options
  relaxed: (s, options = {}) ->
    module.exports.parse s, _.defaults options,
      dateParser: (s) -> Date.parse s
      dateRegex: null
      relaxedWhitespace: true
      requireCompletionDate: false
      ignorePriorityCase: true
      heirarchical: false
      inherit: false
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