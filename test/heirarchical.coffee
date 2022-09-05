assert = require "assert"
parser = require "../lib/parser"

describe "heirarchical mode parser", ->

  it "should parse parallel tasks into an array", ->
    result = parser.relaxed """
      Task A
      Task B
    """, hierarchical: true

    assert.equal result[0].text, "Task A"
    assert.equal result[1].text, "Task B"

  it "should parse indented tasks as subtasks", ->
    result = parser.relaxed """
      Task A
        Task B
      Task C
       Task D
             Task E
            Task F
             Task G
      Task H
    """, hierarchical: true

    assert.equal result[0].text, "Task A"
    assert.equal result[1].text, "Task C"
    assert.equal result[2].text, "Task H"
    assert.equal result[2].subtasks.length, 0
    assert.equal result.length, 3

    assert.equal result[0].subtasks[0].text, "Task B"
    assert.equal result[0].subtasks.length, 1

    assert.equal result[1].subtasks[0].text, "Task D"
    assert.equal result[1].subtasks[0].subtasks[0].text, "Task E"
    assert.equal result[1].subtasks[0].subtasks[1].text, "Task F"
    # even though G is by indent a sibling to E, should only consider the relationship to the parent F
    assert.equal result[1].subtasks[0].subtasks[1].subtasks[0].text, "Task G"

  it "should detect indentation correctly", ->
    # if line starts with x, then count the whitespace after it + 1 (for the x)
    # if line starts with a space, then count the number of leading whitespace characters

    # these should be siblings
    result = parser.relaxed """
      x Task A
        Task B
    """, hierarchical: true
    assert.equal result[0].indentLevel, 2
    assert.equal result[0].subtasks.length, 0
    assert.equal result[1].indentLevel, 2
    assert.equal result[1].subtasks.length, 0

    result = parser.relaxed """
      x Task A
      x   Task B
    """, hierarchical: true
    assert.equal result[0].indentLevel, 2
    assert.equal result[0].subtasks[0].text, "Task B"
    assert.equal result[0].subtasks[0].indentLevel, 4

    # these are siblings because according to the rules above, both are indent level 2
    result = parser.relaxed """
      x Task A
        x Task B
    """, hierarchical: true
    assert.equal result[0].indentLevel, 2
    assert.equal result[0].subtasks.length, 0
    assert.equal result[1].indentLevel, 2
    assert.equal result[1].subtasks.length, 0

    # but if we lead them with whitespace, it's clear we want x's at the start of the task
    result = parser.relaxed "  x Task A\n    x Task B\n    Task C", hierarchical: true
    assert.equal result[0].subtasks[0].text, "Task B"
    assert.equal result[0].subtasks[1].text, "Task C"

  it "should still detect metadata", ->
    result = parser.relaxed """
      (A) Task A
        (B) @context1 Task B +Project1 +Project2
    """, hierarchical: true
    assert.equal result[0].priority, "A"
    assert.equal result[0].subtasks[0].priority, "B"
    assert.equal result[0].subtasks[0].contexts[0], "context1"
    assert.equal result[0].subtasks[0].projects[1], "Project2"

  it "should support inherited traits from parents", ->
    result = parser.relaxed """
      (A) Task A +BigProject @context1 due:tomorrow t:wednesday
        Task B +SubProject @context2 due:today
    """, hierarchical: true, inherit: true

    assert.deepEqual result[0].subtasks[0].contexts, ["context1", "context2"]
    assert.deepEqual result[0].subtasks[0].projects, ["BigProject", "SubProject"]
    # subtask metadata should shadow parents
    assert.equal result[0].subtasks[0].metadata["due"], "today"
    assert.equal result[0].subtasks[0].metadata["t"], "wednesday"
    assert.equal result[0].subtasks[0].priority, "A"

  it "should still correctly parse canonical format", ->
    result = parser.parse """
      Task A
        x Task B
    """, hierarchical: true
    # in canonical mode, Task B is not complete because it has no completion date
    assert.equal result[0].subtasks[0].text, "x Task B"
    assert.equal result[0].subtasks[0].complete, false

    # hierarchical mode implies relaxed whitespace
    result = parser.parse """
      Task A
        x 2008-01-04   (B)   2008-01-02  Task B  @context  +Project
    """, hierarchical: true
    assert.equal result[0].subtasks[0].text, "Task B  @context  +Project"
    assert.equal result[0].subtasks[0].complete, true
    assert.deepEqual result[0].subtasks[0].contexts, ["context"]
    assert.deepEqual result[0].subtasks[0].projects, ["Project"]

  it "should propagate single-trait parents", ->
    result = parser.parse """
      @bank
        deposit pay cheque
        get some cash to pay back @Cathy
    """, hierarchical: true, inherit: true
    assert.equal result[0].text, "@bank"
    assert.deepEqual result[0].subtasks[1].contexts, ["bank", "Cathy"]