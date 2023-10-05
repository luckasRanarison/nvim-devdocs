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
      expected = "![alt](link)\n",
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
      desc = "<pre> with tag children",
      input =
      [[<pre class="language-svelte"><code><span class="token tag"><span class="token tag"><span class="token punctuation">&lt;</span>script</span><span class="token punctuation">&gt;</span></span><span class="token script"><span class="token language-javascript">
  <span class="token keyword">import</span> <span class="token punctuation">{</span> getAllContexts <span class="token punctuation">}</span> <span class="token keyword">from</span> <span class="token string">'svelte'</span><span class="token punctuation">;</span>

  <span class="token keyword">const</span> contexts <span class="token operator">=</span> <span class="token function">getAllContexts</span><span class="token punctuation">(</span><span class="token punctuation">)</span><span class="token punctuation">;</span>
</span></span><span class="token tag"><span class="token tag"><span class="token punctuation">&lt;/</span>script</span><span class="token punctuation">&gt;</span></span></code><button type="button" class="_pre-clip" title="Copy to clipboard" aria-label="Copy to clipboard"><svg><use xlink:href="#icon-copy"></use></svg></button></pre>]],
      expected = [[

```svelte
<script>
  import { getAllContexts } from 'svelte';

  const contexts = getAllContexts();
</script>
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
