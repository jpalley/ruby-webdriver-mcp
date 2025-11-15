# MCP Tool Descriptions - Updated with Selector Examples

## Summary

Updated all MCP tool descriptions related to element finding to provide clear, concise instructions with concrete examples of how to format selectors.

## Updated Tools

### 1. **find_element**

**New Description:**
> Find an element on the page. Returns element_id for use with other tools. Strategies: id (fast), css (#id, .class, tag[attr='val']), xpath (use single quotes: "//button[@id='btn']"), link_text, partial_link_text, tag_name, class, name. XPath examples: //div[@class='container']//button, //button[contains(text(),'Click')]

**Key Improvements:**
- ✅ Shows speed tip: "id (fast)"
- ✅ Inline CSS examples: `#id`, `.class`, `tag[attr='val']`
- ✅ Critical XPath tip: "use single quotes"
- ✅ Concrete XPath examples for common patterns

**Parameter Updates:**
- `strategy`: Simplified list without redundant variations
- `value`: Explicit formatting examples for xpath and css

---

### 2. **find_and_click**

**New Description:**
> Find an element and click it atomically (prevents stale element errors). Strategies: id (recommended), css (#id, .class), xpath (use single quotes: "//button[@id='submit']"), link_text, partial_link_text. Common: id='submit-btn', css='button.primary', xpath="//button[text()='Submit']", link_text='Click Here'

**Key Improvements:**
- ✅ Recommends "id" strategy
- ✅ Shows common real-world examples
- ✅ Emphasizes atomic operation benefit
- ✅ Multiple strategy examples in one line

**Parameter Updates:**
- `value`: Examples for all common patterns: `"button#test"`, `".class-name"`, `"[data-id='value']"`

---

### 3. **click_element**

**New Description:**
> Click a previously found element. Note: For better reliability, use find_and_click instead. Requires element_id from find_element (format: 'element_0', 'element_1', etc). May fail with stale element error if page changed since find_element was called.

**Key Improvements:**
- ✅ Recommends find_and_click for better reliability
- ✅ Shows element_id format explicitly
- ✅ Warns about stale element errors
- ✅ Clarifies the workflow

**Parameter Updates:**
- `element_id`: Shows format `'element_0'` and recommends find_and_click

---

### 4. **send_keys**

**New Description:**
> Type text into a previously found input element. First use find_element with strategy='name' or 'css' to find the input (e.g., name='username', css='input[type="email"]'), then use the returned element_id here.

**Key Improvements:**
- ✅ Describes the two-step workflow clearly
- ✅ Shows best strategies for inputs: `name` and `css`
- ✅ Concrete examples: `name='username'`, `css='input[type="email"]'`
- ✅ Clarifies it's for input elements

**Parameter Updates:**
- `element_id`: Shows format and references workflow

---

## Comparison: Before vs After

### Before (find_element)
```
Description: "Find an element on the page"
Strategy: "Locator strategy: id, name, class, css, xpath, link_text, tag_name"
Value: "The value to search for using the strategy"
```

### After (find_element)
```
Description: "Find an element on the page. Returns element_id for use with other tools.
             Strategies: id (fast), css (#id, .class, tag[attr='val']),
             xpath (use single quotes: "//button[@id='btn']"), link_text, partial_link_text,
             tag_name, class, name. XPath examples: //div[@class='container']//button,
             //button[contains(text(),'Click')]"

Strategy: "Locator strategy: id, css, xpath, link_text, partial_link_text, tag_name, class, name"
Value: "Selector value. For xpath use single quotes inside: \"//button[@id='test']\".
        For css use standard syntax: \"button#test\" or \".class-name\""
```

---

## Benefits for LLM Usage

### 1. **Immediate Understanding**
LLMs can see examples inline without needing to guess formatting:
- XPath: `"//button[@id='submit']"` ✅
- CSS: `"button#test"` ✅
- Not: `//button[@id="test"]` ❌ (breaks JSON)

### 2. **Best Practice Guidance**
- Recommends `id` as fastest
- Suggests `find_and_click` over separate find/click
- Shows when to use each strategy

### 3. **Common Patterns**
Shows real-world examples:
- `css='button.primary'`
- `xpath="//button[text()='Submit']"`
- `name='username'`
- `css='input[type="email"]'`

### 4. **Error Prevention**
- Warns about XPath quote escaping
- Shows element_id format
- Mentions stale element errors

---

## Test Coverage

All tests passing:
- ✅ 8/8 MCP find_and_click tests
- ✅ 16/16 integration find_element tests
- ✅ 12/12 MCP find_element strategy tests
- ✅ Tool descriptions properly registered

---

## Usage Examples for LLMs

### Example 1: Find and click a button by ID
```json
{
  "tool": "find_and_click",
  "arguments": {
    "session_id": "session_abc123",
    "strategy": "id",
    "value": "submit-btn"
  }
}
```

### Example 2: Find input by name, then type
```json
// Step 1: Find
{
  "tool": "find_element",
  "arguments": {
    "session_id": "session_abc123",
    "strategy": "name",
    "value": "username"
  }
}
// Response: {"element_id": "element_0", ...}

// Step 2: Type
{
  "tool": "send_keys",
  "arguments": {
    "session_id": "session_abc123",
    "element_id": "element_0",
    "text": "john@example.com"
  }
}
```

### Example 3: Find button by XPath with text
```json
{
  "tool": "find_and_click",
  "arguments": {
    "session_id": "session_abc123",
    "strategy": "xpath",
    "value": "//button[contains(text(),'Submit')]"
  }
}
```

### Example 4: Find by CSS selector
```json
{
  "tool": "find_element",
  "arguments": {
    "session_id": "session_abc123",
    "strategy": "css",
    "value": "input[type='email']"
  }
}
```

---

## LLM Prompt Integration

These descriptions are now visible to LLMs in the MCP tool list. When an LLM sees:

```
find_element: "Find an element on the page. Returns element_id for use with other tools.
               Strategies: id (fast), css (#id, .class, tag[attr='val']),
               xpath (use single quotes: \"//button[@id='btn']\"), ..."
```

It immediately understands:
1. What the tool returns (`element_id`)
2. Which strategies are available
3. How to format each strategy
4. Common patterns and best practices

---

## Files Modified

1. `lib/selenium_webdriver_mcp/tools/find_element_tool.rb`
   - Enhanced description with examples
   - Updated argument descriptions

2. `lib/selenium_webdriver_mcp/tools/find_and_click_tool.rb`
   - Added strategy recommendations
   - Included common usage patterns

3. `lib/selenium_webdriver_mcp/tools/click_tool.rb`
   - Clarified workflow
   - Recommended find_and_click alternative

4. `lib/selenium_webdriver_mcp/tools/send_keys_tool.rb`
   - Described two-step workflow
   - Added input-specific examples

---

## Next Steps

These updated descriptions will:
- ✅ Help LLMs format selectors correctly the first time
- ✅ Reduce trial-and-error with XPath quote escaping
- ✅ Guide LLMs toward best practices (id > css > xpath)
- ✅ Clarify the workflow for multi-step operations

The descriptions are now **self-documenting** - LLMs can read them and immediately know how to use the tools correctly.
