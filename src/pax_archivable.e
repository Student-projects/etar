note
	description: "[
		ARCHIVABLE for pax headers, mainly used by PAX_HEADER_WRITER
		
		A pax archivable models the pax extended header payload
	]"
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	PAX_ARCHIVABLE

inherit
	ARCHIVABLE

create
	make_empty,
	make_from_payload

feature {NONE} -- Initialization

	make_empty
			-- Create new pax archivable with empty payload
		do
			create payload.make_empty
		end

	make_from_payload (a_payload: STRING_8)
			-- Create new pax archivable with `a_payload' as payload
		do
			make_empty
			payload := a_payload
		end

feature -- Status

	required_blocks: INTEGER
			-- Indicates how many payload blocks this instance needs
		do
			Result := needed_blocks (payload.count)
		end

	header: TAR_HEADER
			-- Header that belongs to the payload
		do
			create Result.make

			Result.set_filename (create {PATH}.make_from_string ({TAR_CONST}.pax_header_filename))
			Result.set_user_id ({TAR_CONST}.pax_header_uid)
			Result.set_group_id ({TAR_CONST}.pax_header_gid)
			Result.set_mode ({TAR_CONST}.pax_header_mode)
			Result.set_size (payload.count.as_natural_64)
		end

feature -- Output

	write_block_to_managed_pointer (p: MANAGED_POINTER; a_pos: INTEGER)
			-- Writes next payload block to `p', starting at `a_pos'
		local
			l_remaining_bytes: INTEGER
		do
			l_remaining_bytes := payload.count - written_blocks * {TAR_CONST}.tar_block_size
			p.put_special_character_8 (payload.area, 0, a_pos, l_remaining_bytes.min ({TAR_CONST}.tar_block_size))

			if l_remaining_bytes <= {TAR_CONST}.tar_block_size then
				-- Fill remaining space of block with '%U'
				pad (p, a_pos + l_remaining_bytes, {TAR_CONST}.tar_block_size - l_remaining_bytes)
			end

			written_blocks := written_blocks + 1
		end

	write_to_managed_pointer (p: MANAGED_POINTER; a_pos: INTEGER)
			-- Writes whole payload to `p', starting at `a_pos'
		do
			p.put_special_character_8 (payload.area, 0, a_pos, payload.count)

			-- pad to full block
			pad (p, a_pos + payload.count, required_blocks * {TAR_CONST}.tar_block_size - payload.count)
		end

feature -- Modification

	put (a_key: STRING_8; a_value: STRING_8)
			-- Put `a_entry' to `payload'
		require
			noting_written: written_blocks = 0
		local
			l_entry_length: INTEGER
		do
				-- Calculate the length part of the entry
			from
				l_entry_length := a_key.count + a_value.count + 3	-- Three extra characters: ' ', '=', '%N'
			until
				l_entry_length = a_key.count + a_value.count + 3 + l_entry_length.out.count
			loop
				l_entry_length := a_key.count + a_value.count + 3 + l_entry_length.out.count
			end

				-- Put entry
			payload.append (l_entry_length.out)
			payload.append_character (' ')
			payload.append (a_key)
			payload.append_character ('=')
			payload.append (a_value)
			payload.append_character ('%N')
		end


feature {NONE} -- Implementation

	payload: STRING_8
			-- pax payload
			-- one line per entry, each entry has the form
			-- length key=value%N
			-- where length is the length of the whole line including
			-- length itself and the %N character

invariant
--	header_is_ustar: {USTAR_HEADER_WRITER}.can_write (header)

end
