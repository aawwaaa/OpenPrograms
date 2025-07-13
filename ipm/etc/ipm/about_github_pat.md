You can use your github PAT like this.

```
    {
        type = "repo",
        id = "github",
        name = "Github",

        file_url = "https://raw.githubusercontent.com/${repo}/${path:1}/${path:2..}",
        dir_url = "https://api.github.com/repos/${repo}/contents/${path:2..}?ref=${path:1}",
        dir_url_format = {
            ["<key>"] = {
                ["type"] = "<is_dir:=dir>",
                ["name"] = "<name>",
            }
        },
        dir_url_response = "json",
        headers = {
            ["Authorization"] = "Bearer <your_pat>",
        }
    },
```

Don't forget to `ipm update` after you change the `sources.list.cfg`.