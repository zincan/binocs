# frozen_string_literal: true

module Binocs
  module TUI
    class SpiritAnimal < Window
      ANIMALS = [
        {
          name: "Fox",
          trait: "Clever & Quick",
          art: <<~ART
               /\\   /\\
              //\\\\_//\\\\     ____
              \\_     _/    /   /
               / * * \\    /^^^]
               \\_\\O/_/    [   ]
                /   \\_    [   /
                \\     \\_  /  /
                 [ [ /  \\/ _/
                _[ [ \\  /_/
          ART
        },
        {
          name: "Owl",
          trait: "Wise & Watchful",
          art: <<~ART
               ,_,
              (O,O)
              (   )
              -"-"-
               ^ ^
          ART
        },
        {
          name: "Cat",
          trait: "Independent & Curious",
          art: <<~ART
               /\\_/\\
              ( o.o )
               > ^ <
              /|   |\\
             (_|   |_)
          ART
        },
        {
          name: "Bear",
          trait: "Strong & Patient",
          art: <<~ART
               ʕ•ᴥ•ʔ
              /|   |\\
              _|   |_
             | |   | |
             |_|   |_|
          ART
        },
        {
          name: "Rabbit",
          trait: "Fast & Alert",
          art: <<~ART
              (\\(\\
              ( -.-)
              o_(")(")
          ART
        },
        {
          name: "Wolf",
          trait: "Loyal & Fierce",
          art: <<~ART
                /\\    /\\
               /  \\  /  \\
              / /\\ \\/ /\\ \\
              \\/  \\  /  \\/
               \\   \\/   /
                \\  **  /
                 \\ -- /
                  \\  /
                   \\/
          ART
        },
        {
          name: "Dragon",
          trait: "Powerful & Legendary",
          art: <<~ART
                         ____
                        / __ \\
               /\\_/\\   | |  | |
              ( o.o )  | |__| |
               > ^ <    \\____/
              /|   |\\  __/  \\__
             / |   | \\/  \\  /  \\
                       \\__/\\__/
          ART
        },
        {
          name: "Turtle",
          trait: "Steady & Resilient",
          art: <<~ART
                   _____
                 /       \\
                |  O   O  |
                 \\   ^   /
               ___/-----\\___
              /   _______   \\
             /___/       \\___\\
          ART
        },
        {
          name: "Phoenix",
          trait: "Reborn & Radiant",
          art: <<~ART
                 ,//
                ///
               ///
              ///     /\\
             ///     //\\\\
            ///     ///\\\\\\
           ///     /// \\\\\\\\
          ///________\\  \\\\\\
          \\\\\\\\\\\\\\\\\\\\\\\\  //
           \\\\\\\\\\\\\\\\\\\\\\\\//
            \\\\\\    \\\\\\//
             \\\\\\    \\//
              \\\\\\   //
               \\\\\\_//
          ART
        },
        {
          name: "Penguin",
          trait: "Social & Adaptable",
          art: <<~ART
                 .--.
                |o_o |
                |:_/ |
               //   \\ \\
              (|     | )
             /'\\_   _/`\\
             \\___)=(___/
          ART
        },
        {
          name: "Octopus",
          trait: "Creative & Flexible",
          art: <<~ART
                  ___
               .-'   '-.
              /  o   o  \\
             |     ^     |
              \\  '---'  /
            /\\/\\/\\/\\/\\/\\/\\
           | | | | | | | |
          ART
        },
        {
          name: "Unicorn",
          trait: "Magical & Unique",
          art: <<~ART
                   \\
                    \\
                     \\\\
                      \\\\
                       >\\/ /\\
                       \\  /  \\
                        \\/    \\
                              `\\
                                \\
          ART
        }
      ].freeze

      attr_accessor :request, :animal

      def initialize(height:, width:, top:, left:)
        super
        @request = nil
        @animal = nil
      end

      def set_request(request)
        @request = request
        @animal = pick_spirit_animal(request)
      end

      def draw
        return unless @animal

        clear
        draw_box("✨ Spirit Animal ✨")

        y = 2

        # Animal name and trait
        name_text = "The #{@animal[:name]}"
        write(y, (@width - name_text.length) / 2, name_text, Colors::HEADER, Curses::A_BOLD)
        y += 1

        trait_text = "\"#{@animal[:trait]}\""
        write(y, (@width - trait_text.length) / 2, trait_text, Colors::STATUS_SUCCESS)
        y += 2

        # Draw ASCII art centered
        art_lines = @animal[:art].lines.map(&:chomp)
        max_art_width = art_lines.map(&:length).max || 0

        art_lines.each do |line|
          x = [(@width - max_art_width) / 2, 2].max
          write(y, x, line, Colors::NORMAL)
          y += 1
        end

        y += 1

        # Request info that determined the animal
        write(y, 2, "Request:", Colors::MUTED, Curses::A_DIM)
        y += 1
        method_str = @request.respond_to?(:read_attribute) ? @request.read_attribute(:method) : @request.method
        info = "#{method_str} #{@request.path[0, 30]}"
        write(y, 2, info, Colors::MUTED, Curses::A_DIM)

        # Footer
        write(@height - 2, 2, "Press any key to close", Colors::KEY_HINT, Curses::A_DIM)

        refresh
      end

      private

      def pick_spirit_animal(request)
        # Create a hash from request attributes to deterministically pick an animal
        seed_string = "#{request.id}#{request.path}#{request.method}#{request.status_code}"
        hash = seed_string.bytes.reduce(0) { |acc, b| acc + b }

        ANIMALS[hash % ANIMALS.length]
      end
    end
  end
end
