module.exports = (robot) ->
  class Entry
    constructor: (name, initiative) ->
      @name = name
      @initiative = parseInt(initiative, 10)

    match: (name) ->
      @name == name

    pass: ->
      @initiative = @initiative - 10

    display: ->
      "`#{@name}` - #{@initiative}"

    dup: ->
      new Entry @name, @initiative

  class InitiativeQueue
    constructor: (hubot_brain) ->
      @store = hubot_brain
      @store['current_round'] ?= []
      @store['lineup'] ?= []

    queue: ->
      @store['current_round']

    sort: (queue) ->
      queue.sort (a, b) ->
        b.initiative - a.initiative

    set: (queue_name, new_queue) ->
      @store[queue_name] = @sort(new_queue).map (entry) -> entry.dup()

    add: (entry) ->
      temp_q = @queue().slice(0)
      temp_q.push(entry)

      @set('current_round', temp_q)
      @set('lineup', temp_q)

    remove: (name) ->
      @remove_from_queue('current_round', name)
      @remove_from_queue('lineup', name)

    remove_from_queue: (queue_name, entry_name) ->
      entry_to_remove = @store[queue_name].filter (entry) ->
        entry.match(entry_name)
      index_for_removal = @store[queue_name].indexOf(entry_to_remove[0])
      @store[queue_name].splice(index_for_removal, 1)

    next: ->
      current_entry = @queue().shift()
      current_entry.pass()

      # If the entry still has initiative, push it back to the queue
      if (current_entry.initiative > 0)
        @queue().push(current_entry)

      # If we don't have anything left in the queue, reset it
      if @queue().length < 1
        @reset_queue()

    reset_queue: ->
      @set('current_round', @store['lineup'])

    clear: ->
      @set('current_round', [])
      @set('lineup', [])

    show_queue: ->
      to_display = @queue().map (entry) -> entry.display()
      to_display[0] = "#{to_display[0]} (*CURRENT PLAYER*)"

      "\n\n\nThe Current Initiative Round is:\n#{to_display.join("\n")}"

  current_initiative_queue = null

  help_commands = """
    The following commands are available for use:

    `add <name> <number>` - Adds an entry for <name> in the initiative queue with number
    `next/pass` - Goes to the next turn in the initiative queue
    `remove <name> from round` - Removes the entry <name> from the round queue (will be restored when the round resets)
    `remove <name> from initiative` - Removes the entry <name> from the entire initiative queue

    `start` - Stops the initiative queue (the Queue will need to be ended with `stop`)
    `stop` - Stops the initiative queue (the Queue will need to be reinstantiated with `start`)

    `show` - Shows the current initiative round
    `commands` - Re-displays this help text
    """

  robot.respond /start/i, (res) ->
    current_initiative_queue = new InitiativeQueue robot.brain

    res.send "*** *Initiative has begun!* ***"
    res.send help_commands

  robot.respond /commands/i, (res) ->
    res.send help_commands

  robot.respond /stop/i, (res) ->
    current_initiative_queue.clear()
    current_initiative_queue = null

    res.send """
    *** *Initiative has now ended* ***

    Use `start` to begin another round.
    """

  robot.respond /show/i, (res) ->
    if current_initiative_queue
      res.send current_initiative_queue.show_queue()
    else
      res.send "We are not currently in initiative"

  robot.respond /add (.*) ([0-9]*)/i, (res) ->
    if current_initiative_queue
      char_name = res.match[1]
      number = res.match[2]
      entry = new Entry char_name, number

      current_initiative_queue.add(entry)
      res.send "#{char_name} has been added to the initiative queue."
      res.send current_initiative_queue.show_queue()
    else
      res.send "We are not currently in initiative"

  robot.respond /(next|pass)/i, (res) ->
    current_initiative_queue.next()
    res.send "The turn has been passed..."
    res.send current_initiative_queue.show_queue()

  robot.respond /remove (.*) from round/i, (res) ->
    if current_initiative_queue
      char_name = res.match[1]

      current_initiative_queue.remove_from_queue('current_round', char_name)

      res.send "#{char_name} has been removed from the round"
      res.send current_initiative_queue.show_queue()
    else
      res.send "We are not currently in initiative"

  robot.respond /remove (.*) from initiative/i, (res) ->
    if current_initiative_queue
      char_name = res.match[1]

      current_initiative_queue.remove(char_name)

      res.send "#{char_name} has been removed from the queue"
      res.send current_initiative_queue.show_queue()
    else
      res.send "We are not currently in initiative"
