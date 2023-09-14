local assert = require("luassert")
local html_to_md = require("nvim-devdocs.transpiler").html_to_md

describe("Transpiler", function()
  local test_cases = {
    {
      desc = "<header>",
      input = "<h1>Hello World</h1>",
      expected = "# Hello World\n\n",
    },
    {
      desc = "<img>",
      input = "<img alt='alt' src='link'/>",
      expected = "![alt](link)",
    },
    {
      desc = "<ul>",
      input = [[
        <ul>
          <li>Item 1</li>
          <li>Item 2</li>
        </ul>
      ]],
      expected = "- Item 1\n- Item 2\n\n",
    },
    {
      desc = "<ul>",
      input = [[
        <ol>
          <li>Item 1</li>
          <li>Item 2</li>
        </ol>
      ]],
      expected = "1. Item 1\n2. Item 2\n\n",
    },
    {
      desc = "<pre>",
      input = [[
        <pre data-language="javascript">console.log("Hello World")</pre>
      ]],
      expected = [[

```javascript
console.log("Hello World")
```
]],
    },
    {
      desc = "<pre> multiline",
      input = [[
<pre data-language="css">
* {
  margin: 0;
  padding: 0;
}</pre>
]],
      expected = [[

```css
* {
  margin: 0;
  padding: 0;
}
```
]],
    },
    {
      desc = "<table>",
      input = [[
        <table>
          <tr>
            <th>Header 1</th>
            <th>Header 2</th>
          </tr>
          <tr>
            <td>Row 1, Cell 1</td>
            <td>Row 1, Cell 2</td>
          </tr>
          <tr>
            <td>Row 2, Cell 1</td>
            <td>Row 2, Cell 2</td>
          </tr>
        </table>
      ]],
      expected = [[| Header 1      | Header 2      |
| ------------- | ------------- |
| Row 1, Cell 1 | Row 1, Cell 2 |
| Row 2, Cell 1 | Row 2, Cell 2 |

]],
    },
  }

  for _, case in ipairs(test_cases) do
    it("converts " .. case.desc, function() assert.same(case.expected, html_to_md(case.input)) end)
  end
end)
