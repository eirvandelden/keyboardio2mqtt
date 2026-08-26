module Keyboardio2mqtt
  # What the daemon remembers about each keyboard between runs: when it was last
  # seen, and what its availability light was last asked for. A memory that cannot
  # be read is set aside and the daemon starts fresh.
  class RememberedState
    SET_ASIDE_SUFFIX = ".unreadable".freeze
    LAST_SEEN = "last_seen".freeze
    LIGHTS = "lights".freeze

    def initialize(path)
      @path = Pathname.new(path)
      @remembered = read
    end

    def for(keyboard_identity, light_name)
      @remembered.dig(keyboard_identity, LIGHTS, light_name)
    end

    def remember(keyboard_identity, light_name, asked)
      lights_of(keyboard_identity)[light_name] = asked
      write
    end

    def seen(keyboard_identity, at)
      about(keyboard_identity)[LAST_SEEN] = at.utc.iso8601
      write
    end

    def known
      @remembered.filter_map do |keyboard_identity, about|
        last_seen = about[LAST_SEEN]
        [ keyboard_identity, Time.iso8601(last_seen) ] if last_seen
      end.to_h
    end

    def forget(keyboard_identity)
      @remembered.delete(keyboard_identity)
      write
    end

    private

    def about(keyboard_identity)
      @remembered[keyboard_identity] ||= {}
    end

    def lights_of(keyboard_identity)
      about(keyboard_identity)[LIGHTS] ||= {}
    end

    def read
      return {} unless @path.exist?

      remembered = parse
      return remembered if remembered.is_a?(Hash)

      set_aside
      {}
    end

    def parse
      JSON.parse(@path.read)
    rescue JSON::ParserError
      nil
    end

    def set_aside
      @path.rename("#{@path}#{SET_ASIDE_SUFFIX}")
    end

    def write
      @path.dirname.mkpath
      @path.write(JSON.generate(@remembered))
    end
  end
end
