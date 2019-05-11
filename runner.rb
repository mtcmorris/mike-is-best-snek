require 'action_cable_client'
require 'pry'

require 'active_support'
require 'active_support/core_ext/hash/indifferent_access'

require_relative "./util/client.rb"
require_relative "./snake_evaluator.rb"

SNEK_HOST = ENV.fetch("SNEK_HOST") { "localhost:8080" }

$client = Client.new("http://#{SNEK_HOST}")

@snake_id = nil
@auth_token = nil

EventMachine.run do
  uri = "ws://#{SNEK_HOST}/cable"
  # We must send an Origin: header else rails is sad
  client = ActionCableClient.new(uri, 'ClientChannel', true, {'Origin' => "foo"})

  client.connected {
    puts "successfully connected. You can watch at http://#{SNEK_HOST}"
    @map = $client.map
  }

  client.disconnected {
    @snake_name, @snake_id, @auth_token, @map = nil
    puts "Doh - disconnected - no snek running at #{SNEK_HOST}"

    sleep 1
    puts "Attempting to reconnect"
    client.reconnect!
  }

  client.received do |payload|
    puts "Received game state"

    if @map
      game_state = payload.fetch("message").with_indifferent_access

      my_snake = game_state.fetch("alive_snakes").detect{|snake| snake.fetch("id") == @snake_id }

      if !my_snake
        # Oh no - there is no my_snake.  Let's make one
        @snake_name = "MIKE SNAKE IS BEST SNAKE"
        puts "Making a new snake: #{@snake_name}"
        response = $client.register_snake(@snake_name)
        @snake_id = response.fetch("snake_id")
        @auth_token = response.fetch("auth_token") # Auth token is required to authenticate moves for our snake
      else
        # Yay - my_snake lives on - Let's get a move
        move = SnakeEvaluator.new(my_snake, game_state, @map).get_intent
        puts "Snake is at: #{my_snake.fetch(:head)} - Moving #{@snake_name} #{move}"
        $client.set_intent(@snake_id, move, @auth_token)
      end
    end
  end
end