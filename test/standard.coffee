assert = require "assert"
parser = require "../lib/parser"

# test the parser against examples from the official format guide:
# https://github.com/ginatrapani/todo.txt-cli/wiki/The-Todo.txt-Format
describe "standard mode parser", ->

  it "should parse one line as one task", ->
    result = parser.parse "Review Tim's pull request"
    assert.deepEqual result, [
      raw: "Review Tim's pull request"
      text: "Review Tim's pull request"
      projects: []
      contexts: []
      complete: false
      dateCreated: null
      dateCompleted: null
      priority: null
      metadata: {}
      subtasks: []
      indentLevel: 0
    ]

  it "should parse one task per line and keep tasks in order", ->
    result = parser.parse """
      Task A
      Task B
    """
    assert.equal result[0].text, "Task A"
    assert.equal result[1].text, "Task B"

    result = parser.parse """
      Task B
      Task A
    """
    assert.equal result[0].text, "Task B"
    assert.equal result[1].text, "Task A"

  it "should find priority at the start of the text", ->
    result = parser.parse "(A) Call Mom"
    assert.equal result[0].priority, "A"

    result = parser.parse "(a) Call Mom",
      ignorePriorityCase: true
    assert.equal result[0].priority, "A"

    # the relaxed parser includes metadata parsing, and the spec suggests using pri for completed task
    result = parser.relaxed "Call Mom pri:A"
    assert.equal result[0].priority, "A"

    result = parser.parse "Really gotta call Mom (A) @phone @someday"
    assert.equal result[0].priority, null

    result = parser.parse "(b) Get back to the boss"
    assert.equal result[0].priority, null

    result = parser.parse "(B)->Submit TPS report"
    assert.equal result[0].priority, null

  it "should find creation date immediately after task priority", ->
    result = parser.parse "2011-03-02 Document +TodoTxt task format"
    assert.equal result[0].dateCreated, "2011-03-02T00:00:00.000Z"

    result = parser.parse "(A) 2011-03-02 Call Mom"
    assert.equal result[0].dateCreated, "2011-03-02T00:00:00.000Z"

    result = parser.parse "(A) Call Mom 2011-03-02"
    assert.equal result[0].dateCreated, null

  it "should find contexts and projects anywhere in the text", ->
    result = parser.parse "@iphone +Family Call Mom +PeaceLoveAndHappiness @phone"
    assert.deepEqual result[0].projects, ["Family", "PeaceLoveAndHappiness"]
    assert.deepEqual result[0].contexts, ["iphone", "phone"]

    result = parser.relaxed "Email SoAndSo at soandso@example.com and learn how to add 2+2"
    assert.deepEqual result[0].contexts, []
    assert.deepEqual result[0].projects, []

  it "should detect completed tasks", ->
    # canonical requires a completion date
    result = parser.parse "x completed task"
    assert.equal result[0].complete, false

    result = parser.parse "x 2011-03-03 Call Mom"
    assert.equal result[0].complete, true

    # relaxed may leave out the completion date
    result = parser.relaxed "x completed task"
    assert.equal result[0].complete, true

    result = parser.relaxed "xylophone lesson"
    assert.equal result[0].complete, false

    result = parser.relaxed "X 2012-01-01 Make resolutions"
    assert.equal result[0].complete, false

    result = parser.relaxed "(A) x Find ticket prices"
    assert.equal result[0].complete, false

  it "should support extension metadata", ->
    # relaxed parser has built-in key:value metadata parser
    result = parser.relaxed "(A) t:2006-07-27 Create TPS Report DUE:2006-08-01"
    assert.deepEqual result[0].metadata,
      t: "2006-07-27"
      due: "2006-08-01"

    # custom extensions
    result = parser.parse "Stop saying #yolo #swag all the time",
      extensions: [
        # a dummy extension to prove later extensions overwrite previous values
        (text) ->
          hashtags: null

        (text) ->
          metadataRegex = /(?:\s+|^)#(\S+)/g
          hashtags: (while match = metadataRegex.exec text
            match[1])
      ]
    assert.deepEqual result[0].metadata.hashtags, ["yolo", "swag"]

  it "should configurably allow relaxed whitespace", ->
    result = parser.parse "    incomplete task   @some-context",
      relaxedWhitespace: true
    assert.equal result[0].text, "incomplete task   @some-context"
    assert.deepEqual result[0].contexts, ["some-context"]

  it "should configurably consider completion date optional", ->
    result = parser.parse "x complete task",
      requireCompletionDate: false
    assert.equal result[0].complete, true

  it "should configurably ignore priority case", ->
    result = parser.parse "(a) complete task",
      ignorePriorityCase: true
    assert.equal result[0].priority, "A"

  it "should configurably support comments", ->
    result = parser.relaxed """
      Task A
      # Task B
        # Task C
    """
    assert.equal result[0].text, "Task A"
    assert.equal result.length, 1

  it "should configurably support custom project and context formats", ->
    result = parser.parse "(B) project(Cleanup) Schedule Goodwill pickup project(GarageSale) @phone",
      projectRegex: /(?:\s+|^)project\((\S+)\)/g
    assert.deepEqual result[0].projects, ["Cleanup", "GarageSale"]

    result = parser.parse "(B) Schedule Goodwill pickup context(phone)",
      contextRegex: /(?:\s+|^)context\((\S+)\)/g
    assert.deepEqual result[0].contexts, ["phone"]

  it "should parse as documented", ->
    example = "x 2014-07-04 (A) 2014-06-19 Document YTD spending on +SocialEvents for @Alex due:2014-08-01"
    result = parser.relaxed example
    assert.deepEqual result, require "./doc-example.json"

  it "should configurably use a custom date pattern", ->
    input = "dAtE(Jan 5) Schedule a meeting with Nancy"
    options =
      dateRegex: /date\(.+\)/
      dateParser: (s) -> s

    # this should not see the creation date, because the case doesnt match
    result = parser.parse input, options
    assert.equal result[0].dateCreated, null

    options.dateRegex = /dAtE\(.+\)/i
    result = parser.parse input, options
    assert.equal result[0].dateCreated, "dAtE(Jan 5)"
