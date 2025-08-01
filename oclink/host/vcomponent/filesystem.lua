local lfs = require("lfs")

return function(address, base)
    local object = {
        address = address,
        type = "filesystem",
        slot = -1
    }

    base = lfs.currentdir() .. "/" .. base

    local handles = {}

    function object.spaceUsed()
        return 0
    end
    function object.open(path, mode)
        local handle = io.open(base .. "/" .. path, mode)
        if not handle then
            return nil
        end
        local id = 1
        repeat
            id = id + 1
        until not handles[id]
        handles[id] = handle
        return id
    end
    function object.seek(id, whence, offset)
        return handles[id]:seek(whence, offset)
    end
    function object.makeDirectory(path)
        return lfs.mkdir(base .. "/" .. path)
    end
    function object.exists(path)
        return lfs.attributes(base .. "/" .. path) ~= nil
    end
    function object.isReadOnly()
        return false
    end
    function object.write(id, value)
        handles[id]:write(value)
        return true
    end
    function object.spaceTotal()
        return 0
    end
    function object.isDirectory(path)
        return lfs.attributes(base .. "/" .. path, "mode") == "directory"
    end
    function object.rename(from, to)
        return lfs.move(base .. "/" .. from, base .. "/" .. to)
    end
    function object.list(path)
        local list = {}
        for file in lfs.dir(base .. "/" .. path) do
            if file == ".." or file == "." then
                goto continue
            end
            list[#list + 1] = file
            ::continue::
        end
        return list
    end
    function object.lastModified(path)
        return lfs.attributes(base .. "/" .. path, "modification")
    end
    function object.getLabel()
        return "OCLink"
    end
    function object.remove(path)
        if object.isDirectory(path) then
            return lfs.rmdir(base .. "/" .. path)
        end
        return os.remove(base .. "/" .. path)
    end
    function object.close(id)
        handles[id]:close()
        handles[id] = nil
    end
    function object.size(path)
        return lfs.attributes(base .. "/" .. path, "size")
    end
    function object.read(id, count)
        count = math.min(count, 65536)
        return handles[id]:read(count)
    end
    function object.setLabel(value)
        return value
    end

    return object
end