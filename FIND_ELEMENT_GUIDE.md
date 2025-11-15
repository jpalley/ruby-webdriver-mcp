# Find Element Guide - How to Locate Elements Correctly

## Overview

The `find_element` and `find_and_click` tools support multiple locator strategies. **All strategies are working correctly**, including XPath. This guide shows you how to use them properly.

## Test Results

✅ **All locator strategies tested and working:**
- 16/16 direct integration tests passing
- 12/12 MCP integration tests passing
- **XPath works perfectly** with single quotes, double quotes, text content, and complex paths

## Supported Strategies

### 1. **ID** (Recommended - Fastest)
Finds element by its `id` attribute.

```json
{
  "strategy": "id",
  "value": "test-button"
}
```

**HTML Example:**
```html
<button id="test-button">Click Me</button>
```

---

### 2. **XPath** (Most Powerful)
Finds element using XPath expressions.

#### Basic XPath with Attribute
```json
{
  "strategy": "xpath",
  "value": "//button[@id='test-button']"
}
```

#### XPath with Text Content
```json
{
  "strategy": "xpath",
  "value": "//button[contains(text(),'Click')]"
}
```

#### Complex XPath
```json
{
  "strategy": "xpath",
  "value": "//div[@id='content']//span[1]"
}
```

#### XPath Examples
```json
// Find by multiple attributes
"//input[@type='text' and @name='username']"

// Find by partial class
"//div[contains(@class, 'modal')]"

// Find descendant
"//form//input[@type='submit']"

// Find by position
"//ul/li[2]"

// Find by parent
"//span[text()='Error']/parent::div"
```

**Important XPath Notes:**
- ✅ Use single quotes inside XPath: `"//button[@id='test-button']"`
- ✅ Or escape double quotes properly: `"//button[@id=\"test-button\"]"`
- ✅ XPath is case-sensitive
- ✅ Use `contains()` for partial matches
- ✅ Use `text()` to match text content

---

### 3. **CSS Selector** (Flexible & Fast)
Finds element using CSS selectors.

#### By ID
```json
{
  "strategy": "css",
  "value": "#test-button"
}
```

#### By Class
```json
{
  "strategy": "css",
  "value": ".description"
}
```

#### By Tag + Attribute
```json
{
  "strategy": "css",
  "value": "button[type='submit']"
}
```

#### Complex Selectors
```json
// Multiple classes
"div.modal.active"

// Descendant
"form input[type='text']"

// Direct child
"ul > li"

// Attribute contains
"a[href*='google']"

// nth-child
"li:nth-child(2)"
```

**CSS Selector Variations (all work):**
- `"css"` ✅
- `"css_selector"` ✅ (auto-normalized to `css`)
- `"cssselector"` ✅ (auto-normalized to `css`)

---

### 4. **Link Text** (For Links)
Finds `<a>` elements by exact text match.

```json
{
  "strategy": "link_text",
  "value": "Go to Form"
}
```

**HTML Example:**
```html
<a href="/form">Go to Form</a>
```

**Variations:**
- `"link_text"` ✅
- `"linktext"` ✅ (auto-normalized)
- `"link"` ✅ (auto-normalized)

---

### 5. **Partial Link Text**
Finds `<a>` elements by partial text match.

```json
{
  "strategy": "partial_link_text",
  "value": "Go to"
}
```

Matches `<a>Go to Form</a>` or `<a>Go to Home</a>`

**Variations:**
- `"partial_link_text"` ✅
- `"partial_link"` ✅ (auto-normalized)
- `"partiallinktext"` ✅ (auto-normalized)

---

### 6. **Tag Name**
Finds first element with matching tag.

```json
{
  "strategy": "tag_name",
  "value": "button"
}
```

**Variations:**
- `"tag_name"` ✅
- `"tagname"` ✅ (auto-normalized)
- `"tag"` ✅ (auto-normalized)

---

### 7. **Class Name**
Finds element by class attribute.

```json
{
  "strategy": "class",
  "value": "description"
}
```

**HTML Example:**
```html
<p class="description">Text</p>
```

**Variations:**
- `"class"` ✅
- `"class_name"` ✅
- `"classname"` ✅ (auto-normalized)

---

### 8. **Name Attribute**
Finds element by `name` attribute (common in forms).

```json
{
  "strategy": "name",
  "value": "username"
}
```

**HTML Example:**
```html
<input name="username" type="text">
```

---

## Common Issues & Solutions

### Issue 1: "XPath doesn't work"

**Problem:** Quote escaping in JSON

❌ **Wrong:**
```json
{
  "strategy": "xpath",
  "value": "//button[@id="test-button"]"  // Breaks JSON!
}
```

✅ **Correct:**
```json
{
  "strategy": "xpath",
  "value": "//button[@id='test-button']"  // Single quotes inside
}
```

Or escape properly:
```json
{
  "strategy": "xpath",
  "value": "//button[@id=\"test-button\"]"  // Escaped double quotes
}
```

---

### Issue 2: "Element not found"

**Possible Causes:**
1. **Timing issue** - Element not loaded yet
2. **Wrong selector** - Typo or incorrect path
3. **Case sensitivity** - XPath is case-sensitive
4. **iframe** - Element is inside an iframe

**Solutions:**

✅ **Check the page is loaded:**
```javascript
// Navigate first, then find
navigate(session_id, url)
// Wait a moment if needed
find_element(session_id, strategy, value)
```

✅ **Verify your selector:**
- Test in browser DevTools console:
  ```javascript
  // For XPath:
  $x("//button[@id='test-button']")

  // For CSS:
  document.querySelector("button#test-button")
  ```

✅ **Use less specific selectors:**
```json
// Instead of:
"//div[@class='modal active']"

// Try:
"//div[contains(@class,'modal')]"
```

---

### Issue 3: "Invalid selector syntax"

**Error Messages (Enhanced):**
```
INVALID SELECTOR after 0.5s
Strategy: xpath, Value: //button[@id='test'
Error: invalid selector: Unable to locate an element...
```

**Solution:** Check your syntax
- XPath: Match all brackets `[]` and quotes
- CSS: Valid CSS selector syntax

---

### Issue 4: "Element found but can't interact"

**Possible Causes:**
1. Element not visible
2. Element disabled
3. Element covered by another element

**Solution:** Check element state
```json
// Find element first
find_element(session_id, "id", "button")
// Response includes: { "displayed": true, "enabled": true }
```

---

## Best Practices

### 1. Prefer Stable Locators

**Priority Order:**
1. **ID** - Most stable, fastest
2. **data-testid** or custom attributes (via CSS/XPath)
3. **CSS class** (if stable)
4. **XPath** - Last resort for complex cases

### 2. Use `find_and_click` for Better Reliability

❌ **Less Reliable** (two separate requests):
```javascript
result = find_element(session_id, "id", "button")
element_id = result.element_id
click_element(session_id, element_id)
```

✅ **More Reliable** (atomic operation):
```javascript
find_and_click(session_id, "id", "button")
```

### 3. Keep Selectors Simple

❌ **Too specific:**
```json
"//html/body/div[1]/div[2]/form/div[3]/button"
```

✅ **Simple & flexible:**
```json
"//button[@type='submit']"
```

### 4. Test Selectors in Browser First

Before using in MCP:
1. Open page in browser
2. Open DevTools Console (F12)
3. Test selector:
   ```javascript
   // XPath
   $x("//button[@id='test']")

   // CSS
   document.querySelector("#test")
   ```
4. If it works in browser, it will work in MCP

---

## Enhanced Error Messages

The system now provides detailed error messages:

### Invalid Selector
```
[Thread 12345] INVALID SELECTOR after 0.5s
[Thread 12345] Strategy: xpath, Value: //button[@id='test'
[Thread 12345] Error: invalid selector: Unable to locate an element...
```

### Element Not Found
```
[Thread 12345] Element NOT FOUND after 5.0s
[Thread 12345] Strategy: id, Value: missing-button
[Thread 12345] Current URL: http://example.com/page
Error: Element not found with id='missing-button' on page http://example.com/page
```

### Strategy Normalization Warning
```
[Thread 12345] ⚠️  Unrecognized strategy 'button_id', passing through to Selenium
```

---

## Examples by Use Case

### Find Submit Button
```json
// By ID
{ "strategy": "id", "value": "submit-btn" }

// By type attribute
{ "strategy": "css", "value": "button[type='submit']" }

// By text content
{ "strategy": "xpath", "value": "//button[contains(text(),'Submit')]" }
```

### Find Input Field
```json
// By name
{ "strategy": "name", "value": "username" }

// By placeholder
{ "strategy": "css", "value": "input[placeholder='Enter username']" }

// By XPath
{ "strategy": "xpath", "value": "//input[@type='text' and @name='username']" }
```

### Find Link
```json
// By exact text
{ "strategy": "link_text", "value": "Read More" }

// By partial text
{ "strategy": "partial_link_text", "value": "Read" }

// By href
{ "strategy": "css", "value": "a[href='/about']" }
```

### Find Dynamically Generated Element
```json
// By data attribute
{ "strategy": "css", "value": "[data-testid='user-profile']" }

// By aria label
{ "strategy": "css", "value": "[aria-label='Close']" }

// By role
{ "strategy": "css", "value": "[role='button']" }
```

---

## Summary

✅ **All strategies work**, including XPath
✅ **Strategy normalization** handles variations (css_selector → css)
✅ **Enhanced error messages** show exactly what failed
✅ **Comprehensive testing** - 28 tests passing

**If you're having trouble:**
1. Check quote escaping in JSON
2. Test selector in browser DevTools first
3. Check the error logs for detailed messages
4. Verify element is visible and loaded
5. Consider using `find_and_click` for atomicity

**XPath works perfectly** - just ensure proper quoting in JSON!
