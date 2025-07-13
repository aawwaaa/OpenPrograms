-- sorry for this, but syntax highlighting
local a_valid_source_list = {
    -- list
    {
        type = "repos",
        id = "open-programs",
        name = "OpenPrograms",
        description = "The OpenPrograms repository", -- optional
        url = "https://raw.githubusercontent.com/OpenPrograms/openprograms.github.io/master/repos.cfg",
        priority = 100, -- optional
        enabled = true, -- optional
        recursive = true, -- optional, allow other `type=repos` in its data and repos' data
    },
    {
        type = "repos",
        id = "example-data",
        name = "Example Data",
        description = "Example Data",
        data = {
            -- here is the thing included in the url, same as this file, or following
            ["Example's Programs"] = {
                repo = "Example/OpenPrograms",
            },
            ["Example's Programs 2"] = {
                programs = {
                    ["program-1"] = {
                        -- same as this file, or following
                        files = {
                            ["master/somefolder/bar.lua"] = "/",--"/" means the file will be placed inside the folder the user specified, defaults to /usr
                            ["master/somefolder/barinfo.txt"] = "//etc", -- double slash for using an absolute path
                            [":master/otherfolder"] = "/share/something", -- A colon marks a folder, will include everything in that folder
                            [":master/otherfolder"] = "//etc/something", -- This also works with absolute paths
                            ["master/somefolder/barlib.lua"] = "/subfolder",--Places the file in a subfolder in the user-specified folder
                            ["?master/somefolder/something.cfg"] = "/" -- This file will only be installed or updated if it doesn't exist already, unless option -f is specified
                        },
                        dependencies = {
                            ["GML"] = "/lib"--This package is installed into the specified subfolder
                        },
                        name = "Package name",--This is for "oppm info"
                        description = "This is an example description",--This is for "oppm info"
                        authors = "Someone, someone else",--This is for "oppm info"
                        note = "Additional installation instructions, general instructions and additional information/notes go here, this is an optional line.",
                        hidden = true, -- Add this optional line to make your package not visible in "oppm list", useful for custom dependency libraries
                        repo="tree/master/somefolder" --Used by the website. This is where the package will link to on the website
                    }
                }
            }
        },
    },
    {
        type = "packages",
        id = "example-packages",
        name = "Example Package",
        description = "Example Package", -- optional
        priority = 100, -- optional
        enabled = true, -- optional 
        recursive = true, -- optional, allow other `type=programs` in its data and repos' data
        url = "https://raw.githubusercontent.com/OpenPrograms/Plan9k/master/programs.cfg",
    },
    {
        type = "repo",
        id = "github",
        name = "Github",

        file_url = "https://raw.githubusercontent.com/${repo}/${path:1}/${path:2..}",
        dir_url = "https://api.github.com/repos/${repo}/contents/${path:2..}?ref=${1}",
        dir_url_format = {
            ["<key>"] = {
                ["download_url"] = "<url>",
                ["type"] = "<type:file=file,dir=dir>",
                ["name"] = "<name>",
                ["size"] = "<size>",
            }
        }
    },
    {
        type = "package",
        id = "example-package",
        name = "Example Package",

        description = "Example Package", -- optional
        authors = "Someone, someone else", -- optional
        note = "Additional installation instructions, general instructions and additional information/notes go here, this is an optional line.", -- optional
        hidden = false, -- optional

        repo = "github:Example/OpenPrograms",

        dependencies = {
            ["GML"] = "/lib", -- This package is installed into the specified subfolder
        },

        files = {
            ["master/somefolder/bar.lua"] = "/",--"/" means the file will be placed inside the folder the user specified, defaults to /usr
            ["master/somefolder/barinfo.txt"] = "//etc", -- double slash for using an absolute path
            [":master/otherfolder"] = "/share/something", -- A colon marks a folder, will include everything in that folder
            [":master/otherfolder"] = "//etc/something", -- This also works with absolute paths
            ["master/somefolder/barlib.lua"] = "/subfolder",--Places the file in a subfolder in the user-specified folder
            ["?master/somefolder/something.cfg"] = "/" -- This file will only be installed or updated if it doesn't exist already, unless option -f is specified
        },

        configure = "/config.lua", -- optional, same as files, but for the configure script
        remove = "/remove.lua", -- optional, same as files, but for the remove script
    }
}
