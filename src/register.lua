-- register.lua -- Hardware device register abstraction

-- ## Register object

Register = {}

--- Create a register `offset` bytes from `base_ptr`.
--- MODE is one of these values:
--- * `RO` - read only.
--- * `RW` - read-write.
--- * `RC` - read-only and return the sum of all values read. This
---   mode is for counter registers that clear back to zero when read.
---
--- Example:
---     register.new("TPT", "Total Packets Transmitted", 0x040D4, ptr, "RC")
function new (name, longname, offset, base_ptr, mode)
   local o = { name=name, longname=longname,
	       ptr=base_ptr + offset/4, mode=mode }
   assert(mode == 'RO' or mode == 'RW' or mode == 'RC')
   setmetatable(o, Register)
   return o
end

--- Register objects are "callable" as functions for convenience:
---     reg()      <=> reg:read()
---     reg(value) <=> reg:write(value)
function Register:__call (value)
   if value == nil then return self:read() else return self:write(value) end
end

--- Registers print as `$NAME:$HEXVALUE` to make debugging easy.
function Register:__tostring ()
   return self.name..":"..bit.tohex(self())
end

function Register:read ()
   local value = self.ptr[0]
   if mode == 'RC' then
      self.acc = self.acc + value
      return self.acc
   else
      return value
   end
end

function Register:write (value)
   assert(self.mode == 'RW')
   self.ptr[0] = value
   return value
end

--- Set and clear specific masked bits.
function Register:set (bitmask) self(bit.bor(self(), bitmask)) end
function Register:clr (bitmask) self(bit.band(self(), bit.bnot(bitmask))) end

--- Block until applying `bitmask` to the register value gives `value`.
--- If `value` is not given then until all bits in the mask are set.
function Register:wait (bitmask, value)
   lib.waitfor(function ()
		  return bit.band(register(), bitmask) == (value or bitmask)
	       end)
end

--- For type `RC`: Reset the accumulator to 0.
function Register:reset () self.acc = nil end

-- ## Define registers from string description.

--- Define a set of registers described by a string.
--- The register objects become named entries in `table`.
---
--- This is an example line for a register description:
---     TXDCTL    0x06028 +0x40*0..127 (RW) Transmit Descriptor Control
---
--- and this is the grammar:
---     Register   ::= Name Offset Indexing Mode Longname
---     Name       ::= <identifier>
---     Indexing   ::= "-"
---                ::= "+" OffsetStep "*" Min ".." Max
---     Mode       ::= "RO" | "RW" | "RC"
---     Longname   ::= <string>
---     Offset ::= OffsetStep ::= Min ::= Max ::= <number>
function define (description, table, base_ptr)
   local pattern = " *(%S+) +(%S+) +(%S+) +(%S+) (.-)\n"
   for name,offset,index,perm,longname in description:gmatch(pattern) do
      table[name] = new(name, longname, base, tonumber(offset), perm)
   end
end

-- Print a pretty-printed register dump for a table of register objects.
function dump (table)
   table = table or r
   print "Register dump:"
   local strings = {}
   for _,reg in pairs(table) do
      if table ~= s or reg() > 0 then
         table.insert(strings, reg)
      end
   end
   table.sort(strings, function(a,b) return a.name < b.name end)
   for _,reg in pairs(strings) do
      if table == s then
         io.write(("%20s %16s %s\n"):format(reg.name, lib.comma_value(reg()), reg.desc))
      else
         io.write(("%20s %s\n"):format(reg, reg.desc))
      end
   end
end
