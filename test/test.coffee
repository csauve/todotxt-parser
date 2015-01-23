assert = require "assert"
parser = require ".."

describe "parser", ->

  it "should parse one line as one task", ->
    result = parser.parse "x (A) 2014-02-01 2013-02-04 Review Tim's pull request"
    assert.deepEqual result, [
      text: "Review Tim's pull request"
      projects: []
      contexts: []
      complete: false
      dateCreated: null
      dateCompleted: null
      priority: null
    ]

  it "should parse one task per line", ->
    result = parser.parse """
      Review Tim's pull request
      Post signs around the neighborhood
    """
    assert.deepEqual result[0],
      text: "Review Tim's pull request"
      projects: []
      contexts: []
      complete: false
      dateCreated: null
      dateCompleted: null
      priority: null

    assert.deepEqual result[1],
      text: "Post signs around the neighborhood"
      projects: []
      contexts: []
      complete: false
      dateCreated: null
      dateCompleted: null
      priority: null

  it "should keep tasks in order", ->
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

  #it "should parse priorities"
