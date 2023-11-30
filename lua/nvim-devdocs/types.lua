---Represents an entry in the Devdocs registery
---@see https://devdocs.io/docs.json
---@class RegisteryEntry
---@field name string
---@field slug string
---@field type string
---@field version number
---@field release string
---@field mtime number
---@field db_size number
---@field links? table<string, string>
---@field attribution string

---Represents an entry in the index.json file
---NOTE: alias and next_path are filled at runtime
---@see nvim_devdocs_path/index.json
---@class DocEntry
---@field name string
---@field path string
---@field link string
---@field alias? string
---@field next_path? string

---Represents a type in the index.json file
---@class DocType
---@field slug string
---@field name string
---@field count number

---Represents a doc in the index.json file
---@class DocIndex
---@field types DocType[]
---@field entries DocEntry[]

---Represents the index.json file
---@alias IndexObject table<string, DocIndex>
