note
	description: "[
		Storage backends for files
	]"
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	FILE_STORAGE_BACKEND

inherit
	STORAGE_BACKEND

create
	make_read,
	make_write

feature {NONE} -- Initialization

	make_read (a_file: FILE)
			-- Create new instance to read from.
			-- This will open a new file to prevent interference with client-side changes
		require
			readable: a_file.is_readable
		do
			create {RAW_FILE} backend.make_open_read (a_file.path.name)
			initialize_internals
		ensure
			readable: is_readable
		end

	make_write (a_file: FILE)
			-- Create new instance to write from
			-- This will open a new file to prevent interference with client-side changes
		require
			writable: a_file.is_writable
		do
			create {RAW_FILE} backend.make_open_write (a_file.path.name)
			initialize_internals
		ensure
			writable: is_writable
		end

	initialize_internals
			-- Initialize internals structures (except `backend')
		do
			create block_buffer.make ({TAR_CONST}.tar_block_size)
			create {ARRAYED_QUEUE [MANAGED_POINTER]} buffer.make (2)
		end

feature -- Status

	archive_finished: BOOLEAN
			-- Indicates whether the next two blocks only contain NUL bytes or the file has not enough characters to read
		local
			l_buffer: MANAGED_POINTER
		do
			Result := backend.is_closed
			if not Result then
					-- Buffer current block
				l_buffer := block_buffer

					-- Read first block
				create block_buffer.make (block_buffer.count)
				read_block

				if block_ready then
						-- Succeeded reading first block
					buffer.put (block_buffer)

						-- Check whether it contains only NUL bytes
					if only_nul_bytes (block_buffer) then
							-- Read second block
						create block_buffer.make (block_buffer.count)
						read_block

						if block_ready then
								-- Succeeded reading second block
							buffer.put (block_buffer)

							if only_nul_bytes (block_buffer) then
								Result := True
							end
						else
								-- Not enough bytes available
							Result := True
						end
					end

				else
						-- Not enough bytes available
					Result := True
				end


					-- Restore current block
				block_buffer := l_buffer
			end
		end

	block_ready: BOOLEAN
			-- Indicate whether there is a block ready
		do
			-- TODO
		end

	is_readable: BOOLEAN
			-- Indicates whether this instance can be read from
		do
			Result := backend.is_open_read
		end

	is_writable: BOOLEAN
			-- Indicates whether this instance can be written to
		do
			Result := backend.is_open_write
		end

feature -- Access

	last_block: MANAGED_POINTER
			-- Return last block that was read
		do
			Result := block_buffer
		end

	read_block
			-- Read next block
		do
			if not buffer.is_empty then
					-- There are buffered items, use them
				block_buffer := buffer.item
				buffer.remove

				has_valid_block := True
			else
					-- No buffered items, read next block
				backend.read_to_managed_pointer (block_buffer, 0, block_buffer.count)
				if backend.bytes_read /= block_buffer.count then
					has_valid_block := False
				end
			end
		end

feature {NONE} -- Implementation

	backend: FILE
			-- file backend

	buffer: QUEUE [MANAGED_POINTER]
			-- buffers blocks that were read ahead

	block_buffer: MANAGED_POINTER
			-- buffer to use for next read operation

	has_valid_block: BOOLEAN
			-- Boolean flag for `block_ready'

	only_nul_bytes (block: MANAGED_POINTER): BOOLEAN
			-- Check whether `block' only consists of NUL bytes
		do
			Result := block.read_special_character_8 (0, block.count).for_all_in_bounds (
				agent (c: CHARACTER_8; i: INTEGER): BOOLEAN
					do
						Result := c = '%U'
					end, 0, block.count)
		end

end