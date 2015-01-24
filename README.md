# todotxt-parser
This is a Node.js module for parsing [the todo.txt format](todotxt.com) created by [Gina Trapani](http://ginatrapani.org/). A variety of configuration options allow it to parse a strict canonical todo.txt format, or a more relaxed version permitting more liberal whitespace, comments, user-defined metadata extensions, and even indented hierarchical tasks with metadata inheritance.

## About the Format
The todo.txt format attempts to maintain all the benefits of portable, human-readable flat files but still provide structured metadata for tools built on the format. For example, your `todo.txt` might look like this:

```
(A) Thank Mom for the meatballs @phone
(B) Schedule Goodwill pickup +GarageSale @phone
Post signs around the neighborhood +GarageSale
@GroceryStore Eskimo pies
Submit expense report for work travel due:2015-01-25
x 2015-01-10 See the new exhibit at the museum
```

Each line in the file is one task, and tasks can have priority (`(A)`), projects (`+GarageSale`), contexts (`@phone`), dates, and other metadata attached to them. Priority, project, and context are 3 main sliceable axes in an effective todo list. See the [todo.txt-cli wiki](https://github.com/ginatrapani/todo.txt-cli/wiki/The-Todo.txt-Format) for full description of the format.

## Installation
```sh
$ npm install todotxt-parser
```

## API
The API consumes a multilined string and returns an array of task objects in the order they appeared in the input:
```js
var parser = require("todotxt-parser");
var tasks = parser.relaxed("x 2014-07-04 (A) 2014-06-19 Document YTD spending on +SocialEvents for @Alex due:2014-08-01");
```
`tasks` looks like this:
```js
[
  {
    // the original untrimmed content of the line
    "raw": "x 2014-07-04 (A) 2014-06-19 Document YTD spending on +SocialEvents for @Alex due:2014-08-01",
    // the trimmed content of the line following the creation date
    "text": "Document YTD spending on +SocialEvents for @Alex due:2014-08-01",
    // projects are found in the `text` field and begin with "+". Empty when none present
    "projects": ["SocialEvents"],
    // contexts are found in the `text` field and begin with "@". Empty when none present
    "contexts": ["Alex"],
    // indicates if the task is marked as completed
    "complete": true,
    // ISO 8601 UTC datetime. Null if not present
    "dateCreated": "2014-06-19T00:00:00.000Z",
    // ISO 8601 UTC datetime. Null if not present
    "dateCompleted": "2014-07-04T00:00:00.000Z",
    // The upper case A-Z priority. Null if not present
    "priority": "A",
    // Stores data parsed by metadata extensions. Defaults to {}
    "metadata": {"due": "2014-08-01"},
    // In hierarchical mode, contains any direct children at a higher indentation level
    "subtasks": [],
    // Indentation level of the task in character columns. See hierarchical mode
    "indentLevel": 0
  }
]
```

You can additionally pass options to `parse` to customize its behaviour. The default options represent strict vanilla `todo.txt` syntax:

```js
parser.parse(input, {
  dateParser: function(s) { return new Date(s).toJSON(); },
  dateRegex: /\d{4}-\d{2}-\d{2}/,
  relaxedWhitespace: false,
  requireCompletionDate: true,
  ignorePriorityCase: false,
  heirarchical: false,
  inherit: false,
  commentRegex: null,
  projectRegex: /\s\+(\S+)/g,
  contextRegex: /\s@(\S+)/g,
  extensions: []
});
```

See the section below for an explanation of each option.

## Options
*(Examples in CoffeeScript)*
### dateParser
A function accepting a string and returning a string, used to convert captured dates for the `dateCreated` and `dateCompleted` fields. It is recommended to return an ISO 8601 UTC datetime for consistency with the default date parser:
```coffee
(s) -> new Date(s).toJSON()
```

### dateRegex
A `RegExp` used to match the creation and completion dates. It should not contain any capture groups. Matches will be parsed by the `dateParser` function. This option defaults to capturing "YYYY-MM-DD" format:
```coffee
/\d{4}-\d{2}-\d{2}/
```

### relaxedWhitespace
The todo.txt specification does not allow for more than 1 space between the completion mark, completion date, priority, creation date, and text. This ensures priorities and tasks line up so lines can be sorted consistently. When `relaxedWhitespace` is changed to `true`, these restrictions are lifted.
```coffee
# none of these longer whitespace gaps would have been valid
parser.parse "x   2013-11-11   (B)   2013-10-11   Clean up",
  relaxedWhitespace: true
# with `relaxedWhitespace`, this is allowed now
parser.parse "    Task B",
  relaxedWhitespace: true
```

### requireCompletionDate
A task is marked completed by adding a lower case "x" marker to the start of the line, followed by a single space and then a completion date. Changing 'requireCompletionDate' to false makes the date optional, allowing tasks like this:
```coffee
parser.parse "x Walk the dog",
  requireCompletionDate: false
```
Note: It is possible for a tasks creation date to become its completion date with this option disabled:
```coffee
# this date will become the creation date
parser.parse "2014-12-02 Task A",
  requireCompletionDate: false

# but now it is the completion date
parser.parse "x 2014-12-02 Task A",
  requireCompletionDate: false

# a priority clears the ambiguity; it is now the creation date
parser.parse "x (A) 2014-12-02 Task A",
  requireCompletionDate: false
```

### ignorePriorityCase
When changed to `true`, both `A-Z` and `a-z` will be allowed for priority. The priority is still always converted to upper case after capture.


### hierarchical
Standard `todo.txt` has no notion of subtasks. Indentation is not allowed because the result is no longer sortable in a meaningful way. If you want to group a set of tasks under one project, each task needs to be annotated with the same `+Project` tag. This can clutter large projects, and it's difficult to see at a glance which tasks are associated by project. If the ability to sort lines alphabetically is not important to you, and you would rather be able to logically group tasks under other tasks, then there is **hierarchical mode**:

```coffee
tasks = parser.relaxed """
  Task A
    Task B
    Task C
      Task D
      Task E
  Task F
""", hierarchical: true
```
Instead of all tasks being stored in a single array, like standard mode with `relaxedWhitespace: true` would return, the `subtasks` field of each task is now used to store child tasks:

*(Fields other than `text`, `indentLevel`, and `subtasks` omitted for brevity)*
```coffee
# parse still returns an array, but it only contains the root level tasks
[
  { text: "Task A", indentLevel: 0, subtasks: [
    { text: "Task B", indentLevel: 2, subtasks: [] }
    { text: "Task C", indentLevel: 2, subtasks: [
      # a task is a leaf when `subtasks` is empty
      { text: "Task D", indentLevel: 4, subtasks: [] }
      { text: "Task E", indentLevel: 4, subtasks: [] }
    ]}
  ]}
  # tasks A and F are siblings
  { text: "Task F", indentLevel: 0, subtasks: [] }
]
```

A task is considered a subtask when its indentation level is greater than its parent's. A new parent is chosen when the indentation level is greater than the previous sibling's indentation level. For example, what is the output of this?

```coffee
tasks = parser.relaxed """
   Task A
  Task B
       Task C
     Task D
       Task E
    Task F
""", hierarchical: true
```

Tasks A and B will be root level siblings even though they are not indented the same amount. Task B has three subtasks: C, D, and F. Task D has a single subtask, E. Even though tasks E and C are indented the same amount, it's their position relative to the previous task that matters. The best practice is to use consistent indentation.

How is `indentLevel` determined? There are two rules:
1. If the line **immediately** begins with the completion mark "x", then `indentLevel` counts it **and** contiguous whitespace characters following it
1. Otherwise, `indentLevel` is the number of leading whitespace characters

This means you can either place the completion mark in the first column, or after the indent:
```
  x Task B
  Task C
    x Task D
    x Task E
    Task F
  Task G
```
is equivalent to:
```
x Task B
  Task C
x   Task D
x   Task E
    Task F
  Task G
```
It's important to note that tasks B and C are siblings. If the intent was to C be a subtask of B, then the first format should have been used (add at least 1 extra column of leading whitespace).

### inherit
The `inherit` option is only applicable to hierarchical mode, and is disabled by default. When enabled, subtasks will inherit the metadata of their ancestors. This includes projects, contexts, completeness, creation and completion dates, priority, and extension metadata. Subtasks can shadow ancestral metadata by explicitly defining it themselves.

```coffee
tasks = parser.relaxed """
  (A) 2014-06-19 Task A +Project1 @context1 due:2014-09-13 t:2014-05-01
    Task B +Project2 due:2014-08-15
""", hierarchical: true, inherit: true
```
Task B will have inhereted task A's metadata:
```coffee
raw: "  Task B +Project2 due:2014-08-15"
text: "Task B +Project2 due:2014-08-15"
# `projects` and `contexts` are considered sets, so you won't
# get duplicates if they're also found in an ancestor
projects: ["Project 1", "Project 2"]
contexts: ["context1"]
complete: false
datecreated: "2014-06-19T00:00:00.000Z"
dateCompleted: null
priority: "A"
# note that `due` is shadowing the parent's value
metadata: {due: "2014-08-15", t: "2014-05-01"}
subtasks: []
indentLevel: 2
```

### commentRegex
This RegExp tests if the line is a comment, and should therefore be ignored. Comments are not part of the todo.txt specification, so this is `null` by default.

### projectRegex, contextRegex
These two RegExp are used to match projects and contexts only inside the task's `text` field, which is anything following the creation date. The defaults match `+Project` and `@context`.
```coffee
projectRegex: /(?:\s|^)\+(\S+)/g
contextRegex: /(?:\s|^)@(\S+)/g
```
When supplying your own expressions, makes sure to have a capture group for the context/project itself, and to enable global matching with the `g` modifier.

### extensions
Extensions are functions that are passed the `text` field of the task and return an object of key-value metadata. The results of all extensions are merged into a task's `metadata` field. The order of functions in `extensions` matters: later functions can overwrite values for a key. No extensions are used by default, but relaxed mode will find any "key:value" pairs with this function:
```coffee
extensions: [
  (text) ->
    metadata = {}
    metadataRegex = /(?:\s+|^)(\S+):(\S+)/g
    while match = metadataRegex.exec text
      metadata[match[1].toLowerCase()] = match[2]
    metadata
]
```

## Future work
* Add a formatter that turns a list or hierarchy of tasks back into a string.

## Testing
Use node package manager to install dependencies and run the tests:
```sh
  $ npm install
  $ npm test
```

## License
See the LICENSE file (MIT).