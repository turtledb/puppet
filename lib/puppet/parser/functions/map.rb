require 'puppet/parser/ast/lambda'

Puppet::Parser::Functions::newfunction(
:map,
:type => :rvalue,
:arity => 2,
:doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each element in a sequence of entries from the first
  argument and returns an array with the result of each invocation of the parameterized block.

  This function takes two mandatory arguments: the first should be an Array, Hash, or enumerable type,
  and the second a parameterized block as produced by the puppet syntax:

        $a.map |$x| { ... }

  When the first argument `$a` is an Array or enumerable type, the block is called with each entry in turn.
  When the first argument is a hash the entry is an array with `[key, value]`.

  *Examples*

        # Turns hash into array of values
        $a.map |$x|{ $x[1] }

        # Turns hash into array of keys
        $a.map |$x| { $x[0] }

  - Since 3.4
  - requires `parser = future`.
  ENDHEREDOC

  receiver = args[0]
  pblock = args[1]

  raise ArgumentError, ("map(): wrong argument type (#{pblock.class}; must be a parameterized block.") unless pblock.respond_to?(:puppet_lambda)

  case receiver
  when Array
  when Hash
  when Puppet::Pops::Types::PAbstractType
    tc = Puppet::Pops::Types::TypeCalculator.new()
    enumerable = tc.enumerable(receiver)
    if enumerable.nil?
      raise ArgumentError, ("map(): given type '#{tc.string(receiver)}' is not enumerable")
    end
    receiver = enumerable.each
  else
    raise ArgumentError, ("map(): wrong argument type (#{receiver.class}; must be an Array, Hash, or enumerable type.")
  end

  receiver.to_a.map {|x| pblock.call(self, x) }
end
