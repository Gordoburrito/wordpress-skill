# ACF Pro JSON Schema - Comprehensive Reference

> This reference documents the complete structure of ACF (Advanced Custom Fields) Pro JSON
> files as used by the Local JSON feature. It is intended as a guide for manually editing
> or programmatically generating ACF field group JSON files.

---

## Table of Contents

1. [Field Group Top-Level Structure](#1-field-group-top-level-structure)
2. [Field Object Structure (Common Properties)](#2-field-object-structure-common-properties)
3. [Field Types and Type-Specific Settings](#3-field-types-and-type-specific-settings)
4. [Nesting Fields: Group, Repeater, Flexible Content](#4-nesting-fields-group-repeater-flexible-content)
5. [Clone Fields](#5-clone-fields)
6. [Conditional Logic Structure](#6-conditional-logic-structure)
7. [Location Rules Structure](#7-location-rules-structure)
8. [Field Key Naming Conventions and Stability](#8-field-key-naming-conventions-and-stability)
9. [The `modified` Timestamp and Local JSON Sync](#9-the-modified-timestamp-and-local-json-sync)
10. [Best Practices](#10-best-practices)

---

## 1. Field Group Top-Level Structure

Every ACF JSON file represents a single field group. The file is named `{key}.json` (e.g.,
`group_abc123def456.json`) and placed in the `acf-json/` directory within the active theme.

### Complete Top-Level Keys

```json
{
    "key": "group_64a1b2c3d4e5f",
    "title": "Page Hero Section",
    "fields": [],
    "location": [],
    "menu_order": 0,
    "position": "normal",
    "style": "default",
    "label_placement": "top",
    "instruction_placement": "label",
    "hide_on_screen": "",
    "active": 1,
    "description": "",
    "show_in_rest": 0,
    "modified": 1700000000
}
```

### Key-by-Key Reference

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `key` | string | **Yes** | Unique identifier. **Must** begin with `group_`. Typically `group_` followed by a hex string from `uniqid()`. |
| `title` | string | **Yes** | Human-readable name shown in the admin UI metabox header. |
| `fields` | array | **Yes** | Array of field objects (see Section 2). |
| `location` | array | **Yes** | Nested array defining where this field group appears (see Section 7). |
| `menu_order` | integer | No | Controls display order when multiple field groups appear on the same screen. Lower numbers display first. Default: `0`. |
| `position` | string | No | Metabox position on the edit screen. Values: `"normal"`, `"acf_after_title"`, `"side"`. Default: `"normal"`. |
| `style` | string | No | Metabox visual style. Values: `"default"` (standard WP metabox), `"seamless"` (no metabox chrome). Default: `"default"`. |
| `label_placement` | string | No | Where field labels appear. Values: `"top"` (above field), `"left"` (beside field). Default: `"top"`. |
| `instruction_placement` | string | No | Where field instructions appear. Values: `"label"` (below label), `"field"` (below field input). Default: `"label"`. |
| `hide_on_screen` | string or array | No | Array of WordPress editor elements to hide when this group is active. Empty string `""` means hide nothing. See below for valid values. |
| `active` | integer (0/1) | No | Whether this field group is active. `1` = active, `0` = disabled. Default: `1`. |
| `description` | string | No | Internal description for developers. Not shown on the edit screen. Default: `""`. |
| `show_in_rest` | integer (0/1) | No | Whether fields in this group appear in the WordPress REST API. Default: `0`. |
| `modified` | integer | No | GMT Unix timestamp of when the field group was last saved. Used for sync detection (see Section 9). |
| `private` | integer (0/1) | No | If `1`, hides this field group from the sync UI. Useful for plugin/theme bundled groups. |

### Valid `hide_on_screen` Values

When `hide_on_screen` is an array, it may contain any of these strings:

- `"permalink"` - Permalink editor
- `"the_content"` - The main content editor (Classic Editor)
- `"excerpt"` - Excerpt metabox
- `"custom_fields"` - Custom fields metabox
- `"discussion"` - Discussion (comments) settings
- `"comments"` - Comments list
- `"revisions"` - Revisions metabox
- `"slug"` - Slug editor
- `"author"` - Author selector
- `"format"` - Post format selector
- `"page_attributes"` - Page attributes (template, parent, order)
- `"featured_image"` - Featured image metabox
- `"categories"` - Categories metabox
- `"tags"` - Tags metabox
- `"send-trackbacks"` - Send trackbacks metabox

**Note**: `hide_on_screen` only applies to the field group with the lowest `menu_order` value
on a given edit screen, and it only affects the Classic Editor experience.

---

## 2. Field Object Structure (Common Properties)

Every field, regardless of type, shares these common properties:

```json
{
    "key": "field_64a1b2c3d4e5f",
    "label": "Heading",
    "name": "heading",
    "aria-label": "",
    "type": "text",
    "instructions": "Enter the section heading.",
    "required": 0,
    "conditional_logic": 0,
    "wrapper": {
        "width": "",
        "class": "",
        "id": ""
    },
    "default_value": "",
    "placeholder": "",
    "prepend": "",
    "append": "",
    "maxlength": "",
    "readonly": 0,
    "disabled": 0
}
```

### Common Properties Reference

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `key` | string | **Yes** | Unique identifier. **Must** begin with `field_`. Must be globally unique across all field groups. |
| `label` | string | **Yes** | Human-readable label shown in the admin UI. |
| `name` | string | **Yes** | Machine name / meta key for database storage. Lowercase, underscores, no spaces. **Cannot be changed** after data is saved without losing access to existing data. |
| `type` | string | **Yes** | The field type identifier (see Section 3). |
| `instructions` | string | No | Help text shown to editors. Default: `""`. |
| `required` | integer (0/1) | No | Whether this field must have a value. Default: `0`. |
| `conditional_logic` | 0 or array | No | Either `0` (disabled) or an array of rule groups (see Section 6). |
| `wrapper` | object | No | Controls the HTML wrapper: `width` (percentage string, e.g., `"50"`), `class` (CSS classes), `id` (HTML ID). |
| `default_value` | mixed | No | Default value when no value has been saved. Type depends on field type. |
| `placeholder` | string | No | Placeholder text for text-style inputs. |
| `prepend` | string | No | Text/HTML prepended before the input (e.g., `"$"`). |
| `append` | string | No | Text/HTML appended after the input (e.g., `"px"`). |
| `maxlength` | string or int | No | Maximum character length. Empty string = no limit. |
| `readonly` | integer (0/1) | No | Makes field read-only. Default: `0`. |
| `disabled` | integer (0/1) | No | Disables the field input. Default: `0`. |

---

## 3. Field Types and Type-Specific Settings

### Basic Fields

#### `text`
Standard single-line text input.
```json
{
    "type": "text",
    "default_value": "",
    "placeholder": "",
    "prepend": "",
    "append": "",
    "maxlength": ""
}
```

#### `textarea`
Multi-line text input.
```json
{
    "type": "textarea",
    "default_value": "",
    "placeholder": "",
    "maxlength": "",
    "rows": "",
    "new_lines": ""
}
```
- `rows`: Number of visible rows (string or int, empty = default)
- `new_lines`: How newlines are formatted on output. Values: `""` (no formatting), `"br"` (convert to `<br>`), `"wpautop"` (wrap in `<p>` tags)

#### `number`
Numeric input with optional constraints.
```json
{
    "type": "number",
    "default_value": "",
    "placeholder": "",
    "prepend": "",
    "append": "",
    "min": "",
    "max": "",
    "step": ""
}
```
- `min`, `max`, `step`: Numeric constraints (string or int, empty = no constraint)

#### `range`
Slider/range input.
```json
{
    "type": "range",
    "default_value": "",
    "prepend": "",
    "append": "",
    "min": "",
    "max": "",
    "step": ""
}
```

#### `email`
Email address input with browser validation.
```json
{
    "type": "email",
    "default_value": "",
    "placeholder": "",
    "prepend": "",
    "append": ""
}
```

#### `url`
URL input.
```json
{
    "type": "url",
    "default_value": "",
    "placeholder": ""
}
```

#### `password`
Password input (masked).
```json
{
    "type": "password",
    "placeholder": "",
    "prepend": "",
    "append": ""
}
```

### Content Fields

#### `wysiwyg`
WordPress visual/text editor.
```json
{
    "type": "wysiwyg",
    "default_value": "",
    "tabs": "all",
    "toolbar": "full",
    "media_upload": 1,
    "delay": 0
}
```
- `tabs`: Which editor tabs to show. Values: `"all"`, `"visual"`, `"text"`
- `toolbar`: Toolbar configuration. Values: `"full"`, `"basic"`
- `media_upload`: Allow media uploads. Values: `1` (yes), `0` (no)
- `delay`: Delay initialization until field is interacted with. Values: `0`, `1`

#### `oembed`
Embed URLs (YouTube, Vimeo, etc.).
```json
{
    "type": "oembed",
    "width": "",
    "height": ""
}
```

#### `image`
Image selection from media library.
```json
{
    "type": "image",
    "return_format": "array",
    "preview_size": "medium",
    "library": "all",
    "min_width": "",
    "min_height": "",
    "min_size": "",
    "max_width": "",
    "max_height": "",
    "max_size": "",
    "mime_types": ""
}
```
- `return_format`: Values: `"array"` (full image data), `"url"` (URL string), `"id"` (attachment ID)
- `preview_size`: WordPress image size for admin preview (e.g., `"thumbnail"`, `"medium"`, `"full"`)
- `library`: Which images are selectable. Values: `"all"`, `"uploadedTo"` (only images attached to current post)
- `min_width`, `min_height`, `max_width`, `max_height`: Pixel constraints (int or empty string)
- `min_size`, `max_size`: File size in MB (int or empty string)
- `mime_types`: Comma-separated allowed MIME types (e.g., `"jpg,png,webp"`)

#### `file`
File selection from media library.
```json
{
    "type": "file",
    "return_format": "array",
    "library": "all",
    "min_size": "",
    "max_size": "",
    "mime_types": ""
}
```
- `return_format`: Values: `"array"`, `"url"`, `"id"`

#### `gallery`
Multiple image selection (ACF Pro).
```json
{
    "type": "gallery",
    "return_format": "array",
    "preview_size": "medium",
    "library": "all",
    "min": "",
    "max": "",
    "min_width": "",
    "min_height": "",
    "min_size": "",
    "max_width": "",
    "max_height": "",
    "max_size": "",
    "mime_types": "",
    "insert": "append"
}
```
- `min`, `max`: Min/max number of images
- `insert`: Where new images are added. Values: `"append"`, `"prepend"`

### Choice Fields

#### `select`
Dropdown select.
```json
{
    "type": "select",
    "choices": {
        "value1": "Label One",
        "value2": "Label Two"
    },
    "default_value": "",
    "return_format": "value",
    "allow_null": 0,
    "multiple": 0,
    "ui": 0,
    "ajax": 0,
    "placeholder": ""
}
```
- `choices`: Object where keys are stored values and values are display labels
- `return_format`: Values: `"value"`, `"label"`, `"array"` (both value and label)
- `allow_null`: Allow empty selection. Values: `0`, `1`
- `multiple`: Allow multiple selections. Values: `0`, `1`
- `ui`: Use enhanced Select2 UI. Values: `0`, `1`
- `ajax`: Load choices via AJAX (requires `ui: 1`). Values: `0`, `1`

#### `checkbox`
Checkbox group.
```json
{
    "type": "checkbox",
    "choices": {
        "value1": "Label One",
        "value2": "Label Two"
    },
    "default_value": [],
    "return_format": "value",
    "layout": "vertical",
    "toggle": 0,
    "allow_custom": 0,
    "save_custom": 0
}
```
- `layout`: Display direction. Values: `"vertical"`, `"horizontal"`
- `toggle`: Show a "Toggle All" option. Values: `0`, `1`
- `allow_custom`: Allow user to enter custom values. Values: `0`, `1`
- `save_custom`: Save custom values to the choices list. Values: `0`, `1`

#### `radio`
Radio button group.
```json
{
    "type": "radio",
    "choices": {
        "value1": "Label One",
        "value2": "Label Two"
    },
    "default_value": "",
    "return_format": "value",
    "layout": "vertical",
    "allow_null": 0,
    "other_choice": 0,
    "save_other_choice": 0
}
```
- `other_choice`: Show an "Other" option with text input. Values: `0`, `1`
- `save_other_choice`: Save custom "Other" values to the choices list. Values: `0`, `1`

#### `button_group`
Segmented button selector.
```json
{
    "type": "button_group",
    "choices": {
        "value1": "Label One",
        "value2": "Label Two"
    },
    "default_value": "",
    "return_format": "value",
    "layout": "horizontal",
    "allow_null": 0
}
```

#### `true_false`
Boolean toggle.
```json
{
    "type": "true_false",
    "default_value": 0,
    "message": "",
    "ui": 0,
    "ui_on_text": "",
    "ui_off_text": ""
}
```
- `message`: Text displayed alongside the toggle/checkbox
- `ui`: Use stylized toggle switch instead of checkbox. Values: `0`, `1`
- `ui_on_text`, `ui_off_text`: Custom labels for toggle states (only when `ui: 1`)

### Relational Fields

#### `link`
URL with title and target.
```json
{
    "type": "link",
    "return_format": "array"
}
```
- `return_format`: Values: `"array"` (returns `{title, url, target}`), `"url"` (URL string only)

#### `post_object`
Select one or more posts.
```json
{
    "type": "post_object",
    "post_type": [],
    "taxonomy": [],
    "return_format": "object",
    "allow_null": 0,
    "multiple": 0,
    "ui": 1
}
```
- `post_type`: Array of post type slugs to filter (empty = all)
- `taxonomy`: Array of taxonomy term strings in `"taxonomy:term"` format to filter
- `return_format`: Values: `"object"` (WP_Post), `"id"` (post ID)

#### `page_link`
Select a page/post URL.
```json
{
    "type": "page_link",
    "post_type": [],
    "taxonomy": [],
    "allow_null": 0,
    "multiple": 0,
    "allow_archives": 1
}
```
- `allow_archives`: Include archive URLs. Values: `0`, `1`

#### `relationship`
Select multiple posts with a two-column interface.
```json
{
    "type": "relationship",
    "post_type": [],
    "taxonomy": [],
    "return_format": "object",
    "min": "",
    "max": "",
    "filters": ["search", "post_type", "taxonomy"],
    "elements": ""
}
```
- `filters`: Array of enabled filter dropdowns. Values: `"search"`, `"post_type"`, `"taxonomy"`
- `elements`: Display elements. Values: `""` (none) or array containing `"featured_image"`

#### `taxonomy`
Select taxonomy terms.
```json
{
    "type": "taxonomy",
    "taxonomy": "category",
    "field_type": "checkbox",
    "return_format": "id",
    "add_term": 1,
    "save_terms": 0,
    "load_terms": 0,
    "allow_null": 0,
    "multiple": 0
}
```
- `taxonomy`: Taxonomy slug (e.g., `"category"`, `"post_tag"`, custom taxonomy slug)
- `field_type`: UI widget. Values: `"checkbox"`, `"multi_select"`, `"radio"`, `"select"`
- `return_format`: Values: `"object"` (WP_Term), `"id"` (term ID)
- `add_term`: Allow creating new terms inline. Values: `0`, `1`
- `save_terms`: Save selected terms as actual post terms. Values: `0`, `1`
- `load_terms`: Load post's terms as the field value. Values: `0`, `1`

#### `user`
Select WordPress users.
```json
{
    "type": "user",
    "role": [],
    "return_format": "array",
    "allow_null": 0,
    "multiple": 0
}
```
- `role`: Array of role slugs to filter (empty = all roles)
- `return_format`: Values: `"array"`, `"object"`, `"id"`

### jQuery / Date & Time Fields

#### `google_map`
Google Maps location picker.
```json
{
    "type": "google_map",
    "center_lat": "",
    "center_lng": "",
    "zoom": "",
    "height": ""
}
```
- `center_lat`, `center_lng`: Default map center coordinates (string or int)
- `zoom`: Default zoom level (string or int)
- `height`: Map height in pixels (string or int)

#### `date_picker`
Date selection.
```json
{
    "type": "date_picker",
    "display_format": "d/m/Y",
    "return_format": "d/m/Y",
    "first_day": 1
}
```
- `display_format`: PHP date format string for admin display
- `return_format`: PHP date format string for template output
- `first_day`: First day of the week. `0` = Sunday, `1` = Monday, ... `6` = Saturday

#### `date_time_picker`
Date and time selection.
```json
{
    "type": "date_time_picker",
    "display_format": "d/m/Y g:i a",
    "return_format": "d/m/Y g:i a",
    "first_day": 1
}
```

#### `time_picker`
Time-only selection.
```json
{
    "type": "time_picker",
    "display_format": "g:i a",
    "return_format": "g:i a"
}
```

#### `color_picker`
Color selection.
```json
{
    "type": "color_picker",
    "default_value": "",
    "enable_opacity": 0,
    "return_format": "string"
}
```

### Layout / UI Fields

These fields do not store data. They are purely for organizing the edit screen.

#### `message`
Display a message to editors.
```json
{
    "type": "message",
    "message": "Please fill in the fields below.",
    "new_lines": "wpautop",
    "esc_html": 0
}
```
- `new_lines`: Values: `""`, `"br"`, `"wpautop"`
- `esc_html`: Whether to escape HTML. Values: `0` (allow HTML), `1` (escape HTML)

#### `accordion`
Collapsible section divider.
```json
{
    "type": "accordion",
    "open": 0,
    "multi_expand": 0,
    "endpoint": 0
}
```
- `open`: Whether section starts open. Values: `0`, `1`
- `multi_expand`: Allow multiple sections open at once. Values: `0`, `1`
- `endpoint`: Marks the end of an accordion section. Values: `0`, `1`

#### `tab`
Tab navigation divider.
```json
{
    "type": "tab",
    "placement": "top",
    "endpoint": 0
}
```
- `placement`: Tab position. Values: `"top"`, `"left"`
- `endpoint`: Start a new tab group. Values: `0`, `1`

### Complete List of ACF Field Type Identifiers

**Basic**: `text`, `textarea`, `number`, `range`, `email`, `url`, `password`

**Content**: `image`, `file`, `wysiwyg`, `oembed`, `gallery` (Pro)

**Choice**: `select`, `checkbox`, `radio`, `button_group`, `true_false`

**Relational**: `link`, `post_object`, `page_link`, `relationship`, `taxonomy`, `user`

**jQuery**: `google_map`, `date_picker`, `date_time_picker`, `time_picker`, `color_picker`

**Layout**: `message`, `accordion`, `tab`, `group`, `repeater` (Pro), `flexible_content` (Pro), `clone` (Pro)

---

## 4. Nesting Fields: Group, Repeater, Flexible Content

### Group Field

The `group` field wraps sub-fields into a logical unit. Data is returned as an associative array.
In the database, meta keys are stored as `{group_name}_{sub_field_name}`.

```json
{
    "key": "field_hero_group",
    "label": "Hero Section",
    "name": "hero",
    "type": "group",
    "layout": "block",
    "sub_fields": [
        {
            "key": "field_hero_title",
            "label": "Title",
            "name": "title",
            "type": "text"
        },
        {
            "key": "field_hero_image",
            "label": "Image",
            "name": "image",
            "type": "image",
            "return_format": "id"
        }
    ]
}
```

**Group-specific settings:**
- `layout`: Display style. Values: `"block"`, `"table"`, `"row"`
- `sub_fields`: Array of child field objects (same structure as any field)

### Repeater Field (Pro)

The `repeater` field allows editors to add/remove rows, each containing the same set of
sub-fields. Data is stored with indexed meta keys: `{repeater_name}_{index}_{sub_field_name}`.

```json
{
    "key": "field_team_members",
    "label": "Team Members",
    "name": "team_members",
    "type": "repeater",
    "layout": "block",
    "button_label": "Add Member",
    "min": 1,
    "max": 20,
    "collapsed": "field_member_name",
    "pagination": 0,
    "rows_per_page": 20,
    "sub_fields": [
        {
            "key": "field_member_name",
            "label": "Name",
            "name": "name",
            "type": "text",
            "required": 1
        },
        {
            "key": "field_member_role",
            "label": "Role",
            "name": "role",
            "type": "text"
        }
    ]
}
```

**Repeater-specific settings:**

| Setting | Type | Description |
|---------|------|-------------|
| `layout` | string | Display style. Values: `"table"`, `"block"`, `"row"` |
| `button_label` | string | Text for the "Add Row" button |
| `min` | int or `""` | Minimum number of rows required |
| `max` | int or `""` | Maximum number of rows allowed |
| `collapsed` | string | Field key of the sub-field shown when a row is collapsed (e.g., `"field_member_name"`) |
| `pagination` | int (0/1) | Enable pagination for large row counts (ACF 6.0+) |
| `rows_per_page` | int | Number of rows per page when pagination is enabled |
| `sub_fields` | array | Array of child field objects |

**Pagination limitations**: Not available inside Flexible Content fields, nested Repeaters,
ACF Blocks, or frontend forms.

### Flexible Content Field (Pro)

The `flexible_content` field defines multiple layout types. Editors can add layouts in any
order and quantity. Each layout has its own set of sub-fields.

```json
{
    "key": "field_page_sections",
    "label": "Page Sections",
    "name": "sections",
    "type": "flexible_content",
    "button_label": "Add Section",
    "min": "",
    "max": "",
    "layouts": {
        "layout_hero": {
            "key": "layout_hero",
            "name": "hero",
            "label": "Hero Banner",
            "display": "block",
            "min": "",
            "max": 1,
            "sub_fields": [
                {
                    "key": "field_hero_heading",
                    "label": "Heading",
                    "name": "heading",
                    "type": "text"
                },
                {
                    "key": "field_hero_bg_image",
                    "label": "Background Image",
                    "name": "background_image",
                    "type": "image",
                    "return_format": "id"
                }
            ]
        },
        "layout_text_block": {
            "key": "layout_text_block",
            "name": "text_block",
            "label": "Text Block",
            "display": "block",
            "min": "",
            "max": "",
            "sub_fields": [
                {
                    "key": "field_text_content",
                    "label": "Content",
                    "name": "content",
                    "type": "wysiwyg"
                }
            ]
        }
    }
}
```

**Flexible Content-specific settings:**

| Setting | Type | Description |
|---------|------|-------------|
| `button_label` | string | Text for the "Add Row"/"Add Layout" button |
| `min` | int or `""` | Minimum total number of layouts required |
| `max` | int or `""` | Maximum total number of layouts allowed |
| `layouts` | object or array | Collection of layout definitions (see below) |

**Layout object:**

| Setting | Type | Required | Description |
|---------|------|----------|-------------|
| `key` | string | **Yes** | Unique identifier. Should begin with `layout_`. |
| `name` | string | **Yes** | Machine name used to identify the layout in code (via `get_row_layout()`). |
| `label` | string | **Yes** | Human-readable label shown in the layout picker. |
| `display` | string | No | Sub-field display style. Values: `"table"`, `"block"`, `"row"`. Default: `"block"`. |
| `min` | int or `""` | No | Minimum instances of this specific layout. |
| `max` | int or `""` | No | Maximum instances of this specific layout. |
| `sub_fields` | array | No | Array of child field objects for this layout. |

**Note on `layouts` format**: ACF exports `layouts` as either an object (keyed by layout key)
or as an array of layout objects. Both formats are accepted when loading JSON. The object
format is more common in exported files.

---

## 5. Clone Fields

The `clone` field (Pro) references existing fields or entire field groups and displays
their fields inline, without duplicating definitions. This is ACF's primary mechanism
for creating reusable field components.

### Clone Field Structure

```json
{
    "key": "field_page_cta_button",
    "label": "CTA Button",
    "name": "cta_button",
    "type": "clone",
    "clone": [
        "group_button_settings"
    ],
    "display": "seamless",
    "layout": "block",
    "prefix_label": 0,
    "prefix_name": 0
}
```

### Clone-Specific Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `clone` | array | `[]` | Array of keys to clone. Can contain `group_*` keys (clones all fields from that field group) or `field_*` keys (clones individual fields). |
| `display` | string | `"seamless"` | How cloned fields appear. `"seamless"` = replaces the clone field entirely with the cloned fields. `"group"` = wraps cloned fields in a group container. |
| `layout` | string | `"block"` | Layout style when `display` is `"group"`. Values: `"block"`, `"table"`, `"row"`. |
| `prefix_label` | int (0/1) | `0` | Prefix cloned field labels with this clone field's label (e.g., "Hero" + "Title" = "Hero Title"). |
| `prefix_name` | int (0/1) | `0` | Prefix cloned field names with this clone field's name for unique database storage (e.g., `hero_title` instead of just `title`). |

### How Clone References Work

The `clone` array accepts two types of keys:

1. **Field Group keys** (`group_*`): Clones ALL fields from the referenced field group.
   ACF uses `acf_is_field_group_key()` to detect these.

2. **Individual Field keys** (`field_*`): Clones a single specific field.
   ACF uses `acf_is_field_key()` to detect these.

```json
{
    "clone": [
        "group_button_settings",
        "field_specific_color_picker"
    ]
}
```

### Display Modes Explained

**Seamless** (`"display": "seamless"`):
- The clone field is completely replaced by the cloned fields
- Cloned fields appear as if they were defined directly in the parent group
- Values are saved as individual top-level meta entries
- Ideal for embedding reusable components inside Repeater/Flexible Content layouts
- Template access: `get_field('title')` (direct access by sub-field name)

**Group** (`"display": "group"`):
- Cloned fields appear inside a collapsible group container
- Values are returned as an array
- Template access: `get_field('cta_button')` returns array, or `get_field('cta_button_title')` with prefix

### Prefix Name Behavior

When `prefix_name` is `1`, the clone field's `name` is prepended to each cloned field's
`name` when saving to the database:

- Clone field name: `hero_button`
- Cloned sub-field name: `text`
- Resulting meta key: `hero_button_text`

This is critical when you clone the same field group multiple times in a single context
(e.g., a "Primary Button" and "Secondary Button" both cloning the same button fields).
Without prefixing, both would write to the same meta keys and conflict.

### Clone Inside Flexible Content (Reusable Layout Pattern)

A powerful pattern for large sites: create a separate field group for each layout type,
then use clone fields inside flexible content layouts to reference them:

```json
{
    "type": "flexible_content",
    "layouts": {
        "layout_hero": {
            "key": "layout_hero",
            "name": "hero",
            "label": "Hero",
            "sub_fields": [
                {
                    "key": "field_hero_clone",
                    "label": "Hero Fields",
                    "name": "hero_fields",
                    "type": "clone",
                    "clone": ["group_layout_hero_fields"],
                    "display": "seamless",
                    "prefix_name": 0
                }
            ]
        }
    }
}
```

This pattern means each layout's fields are defined in their own dedicated field group JSON
file, keeping the main flexible content definition lean and each layout independently
maintainable.

---

## 6. Conditional Logic Structure

Conditional logic controls whether a field is visible based on the values of other fields
in the same field group.

### Structure

```json
{
    "conditional_logic": [
        [
            {
                "field": "field_abc123",
                "operator": "==",
                "value": "yes"
            }
        ]
    ]
}
```

### How AND/OR Works

The conditional logic array uses **nested arrays** with the following logic:

- **Outer array**: Each element is an **OR** group (any group matching = field is shown)
- **Inner array**: Each element is an **AND** rule (all rules must match within the group)

```json
{
    "conditional_logic": [
        [
            {"field": "field_show_cta", "operator": "==", "value": "1"},
            {"field": "field_cta_type", "operator": "==", "value": "button"}
        ],
        [
            {"field": "field_override", "operator": "==", "value": "1"}
        ]
    ]
}
```

This reads as: Show this field when **(show_cta is 1 AND cta_type is "button") OR (override is 1)**.

### Rule Object

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `field` | string | **Yes** | The `key` of the field to evaluate (e.g., `"field_abc123"`). Must be a field in the same field group or parent context. |
| `operator` | string | **Yes** | Comparison operator. |
| `value` | string | **Yes** | The value to compare against. |

### Available Operators

| Operator | Description |
|----------|-------------|
| `"=="` | Value is equal to |
| `"!="` | Value is not equal to |
| `"hasValue"` | Has any value (non-empty) |
| `"hasNoValue"` | Has no value (empty) |
| `"pattern"` | Value matches regex pattern |
| `"contains"` | Value contains substring |

**Important**: Not all operators work with all field types. Fields like `image`, `file`,
`date_picker`, and `google_map` only support `"hasValue"` and `"hasNoValue"` because their
values are not simple strings. Toggle-style fields (`true_false`, `select`, `radio`,
`checkbox`, `button_group`) support all operators.

### Disabling Conditional Logic

Set to integer `0` (not `false`, not `null`, not empty array):

```json
{
    "conditional_logic": 0
}
```

---

## 7. Location Rules Structure

Location rules determine where (on which admin screens) a field group is displayed.

### Structure

```json
{
    "location": [
        [
            {
                "param": "post_type",
                "operator": "==",
                "value": "page"
            }
        ]
    ]
}
```

### AND/OR Logic

Same nesting pattern as conditional logic:

- **Outer array**: OR groups (field group shows if **any** group matches)
- **Inner array**: AND rules (all rules within a group must match)

```json
{
    "location": [
        [
            {"param": "post_type", "operator": "==", "value": "page"},
            {"param": "page_template", "operator": "==", "value": "templates/landing.php"}
        ],
        [
            {"param": "post_type", "operator": "==", "value": "portfolio"}
        ],
        [
            {"param": "options_page", "operator": "==", "value": "acf-options-theme-settings"}
        ]
    ]
}
```

This reads as: Show this field group when **(post type is "page" AND template is
"landing.php") OR (post type is "portfolio") OR (on the "Theme Settings" options page)**.

### Rule Object

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `param` | string | **Yes** | The location parameter type. |
| `operator` | string | **Yes** | Values: `"=="` (is equal to), `"!="` (is not equal to). |
| `value` | string | **Yes** | The value to match against. |

### Available Location Parameters (`param` values)

**Post:**
- `"post_type"` - Match by post type slug (e.g., `"post"`, `"page"`, `"product"`)
- `"post_template"` - Match by post template file
- `"post_status"` - Match by post status (e.g., `"publish"`, `"draft"`)
- `"post_format"` - Match by post format
- `"post_category"` - Match by post category
- `"post_taxonomy"` - Match by taxonomy term (value format: `"taxonomy:term_slug"`)
- `"post"` - Match specific post by ID

**Page:**
- `"page_template"` - Match by page template file
- `"page_type"` - Match by page type (e.g., `"front_page"`, `"top_level"`, `"parent"`, `"child"`)
- `"page_parent"` - Match by parent page ID
- `"page"` - Match specific page by ID

**User:**
- `"current_user"` - Match by current logged-in user
- `"current_user_role"` - Match by current user's role
- `"user_form"` - Match user edit screens (e.g., `"all"`, `"edit"`, `"add"`, `"register"`)
- `"user_role"` - Match by the role of the user being edited

**Forms:**
- `"taxonomy"` - Match taxonomy term edit screens
- `"attachment"` - Match media attachment edit screens
- `"comment"` - Match comment edit screens
- `"widget"` - Match widget forms
- `"nav_menu"` - Match navigation menu screens
- `"nav_menu_item"` - Match individual menu items
- `"options_page"` - Match ACF Options Pages (value is the options page slug)

**Block:**
- `"block"` - Match ACF Block type (value is block name, e.g., `"acf/hero"`)

---

## 8. Field Key Naming Conventions and Stability

### Key Prefixes

ACF uses specific prefixes to identify different types of objects:

| Prefix | Used For | Example |
|--------|----------|---------|
| `group_` | Field groups | `group_64a1b2c3d4e5f` |
| `field_` | All field types | `field_64a1b2c3d4e5f` |
| `layout_` | Flexible content layouts | `layout_64a1b2c3d4e5f` |

### How ACF Generates Keys

ACF uses PHP's `uniqid()` function to generate the hex portion of keys. This produces a
13-character hexadecimal string based on the current microsecond timestamp. The result is
keys like:

```
group_64a1b2c3d4e5f
field_64a1b2c3d5a01
layout_64a1b2c3d5b23
```

### Why Key Stability Matters

**Field keys are the link between field definitions and stored data.** When a value is saved
for a field, ACF stores a reference meta entry mapping the field `name` to its `key`:

```
Meta key: _heading        (reference entry)
Meta value: field_abc123  (points to the field definition)

Meta key: heading         (actual value)
Meta value: "Welcome"
```

If you change a field's `key`, ACF can no longer find the field definition for existing data.
This means:

- Existing values become inaccessible through ACF's API
- Conditional logic referencing that key breaks
- Clone fields referencing that key break
- Repeater `collapsed` references break

**Rules for field keys:**

1. **Never change a key** after data has been saved against it.
2. **Keys must be globally unique** across all field groups in the installation.
3. **Keys must start with the correct prefix** (`field_`, `group_`, `layout_`).
4. **Keys should contain only** lowercase alphanumeric characters and underscores.
5. **Field `name` values should also never change** after data exists, as the `name` is the
   actual meta key used for database storage.

### Approaches to Key Generation for Manual JSON

**Approach 1: Use `uniqid()`-style hex strings (matches ACF's behavior)**
```
field_64a1b2c3d4e5f
```
You can generate these with any tool that produces hex timestamps. The key requirement is
uniqueness, not the specific format.

**Approach 2: Use descriptive, namespaced keys (more readable)**
```
field_hero_heading
field_hero_background_image
group_hero_section
layout_hero_banner
```
This is valid and more maintainable for hand-written JSON. Keys just need to be unique and
start with the correct prefix.

**Approach 3: Hierarchical namespacing (recommended for large projects)**
```
group_page_content
field_page_content_sections                    (flexible content)
layout_page_content_sections_hero              (layout)
field_page_content_sections_hero_title          (field in layout)
field_page_content_sections_hero_image          (field in layout)
layout_page_content_sections_text_block        (another layout)
field_page_content_sections_text_block_content  (field in layout)
```
This makes keys predictable and avoids collisions naturally through structural uniqueness.

---

## 9. The `modified` Timestamp and Local JSON Sync

### How Local JSON Works

When ACF is active, it:

1. **On save**: Writes a `.json` file to the `acf-json/` directory whenever a field group,
   post type, taxonomy, or options page is saved in the admin.
2. **On load**: Reads all `.json` files from `acf-json/` during ACF initialization,
   bypassing database queries for field definitions.

### The `modified` Timestamp

The `modified` value is a **GMT Unix timestamp** (integer) representing when the field group
was last saved. Example:

```json
{
    "modified": 1700000000
}
```

This equals `2023-11-14T22:13:20+00:00` in ISO 8601.

### Sync Detection Logic

ACF determines if a JSON file needs to be synced to the database by comparing:

1. The `modified` value in the JSON file
2. The `post_modified_gmt` value of the corresponding post in the database (field groups are
   stored as `acf-field-group` custom post type entries)

**A field group is "available for sync" when:**
- The JSON file's `modified` timestamp is **higher** than the database post's modification
  date, **OR**
- The field group exists in JSON but **does not exist** in the database (matched by the
  `key` value)

### Practical Implications for Manual JSON Editing

When manually editing JSON files:

1. **Always update `modified`** to a new, higher Unix timestamp. If you don't, ACF won't
   detect the change and won't offer to sync it.
2. **Use current timestamps**: `date +%s` in a terminal gives you the current Unix timestamp.
3. **The sync is not automatic**: After editing JSON files and loading a WordPress admin page,
   you must go to **ACF > Field Groups** and click "Sync" for each changed group, or use
   "Sync All".
4. **JSON takes precedence in the sync process**: When you sync, ACF overwrites the database
   version with the JSON version.

### The `private` Flag

Setting `"private": 1` in the JSON prevents the field group from appearing in the sync UI.
This is used by themes and plugins that bundle field groups and don't want users to modify
them:

```json
{
    "key": "group_bundled_fields",
    "title": "Theme Fields",
    "private": 1,
    "modified": 1700000000,
    "fields": []
}
```

### File Naming

JSON files are named `{key}.json` by default. For example:
- `group_64a1b2c3d4e5f.json`

The filename can be customized with the `acf/json/save_file_name` filter, but for manual
editing, matching the key ensures ACF can find the file.

---

## 10. Best Practices

### Field Naming

1. **Use lowercase with underscores**: `hero_heading`, not `heroHeading` or `Hero-Heading`.
   ACF field names map directly to PHP variables and meta keys.

2. **Name by purpose, not location**: Use `hero_image` instead of `home_page_hero_image`.
   If the field is already scoped to a specific post via location rules, the context is
   implicit.

3. **Avoid repeating parent names in sub-fields**: Inside a repeater named `team_members`,
   use `name` and `role`, not `team_member_name` and `team_member_role`. ACF already
   composes the full meta key as `team_members_0_name`.

4. **Use prefixes for top-level fields**: Prefix top-level field names to avoid collisions
   with other plugins (e.g., `brand_primary_color` instead of `primary_color`).

### Reusable Components

**Clone fields** are the primary tool for reuse:

- Create a standalone field group for each reusable component (e.g., "Component: Button",
  "Component: CTA")
- Reference via clone fields using the `group_*` key
- Use `prefix_name: 1` when the same component appears multiple times on a single screen

**Clone + Flexible Content pattern** for page builders:

- Create one field group per layout type: "Layout: Hero", "Layout: Text Block", etc.
- Create a master field group with a single flexible content field
- Each flexible content layout contains a single seamless clone field referencing the
  corresponding layout field group
- Benefits: each layout is independently editable, the master flexible content stays small,
  new layouts only require a new field group

**When to use clone vs. flexible content layouts directly:**

| Scenario | Use |
|----------|-----|
| Same fields needed in multiple unrelated field groups | Clone |
| Same fields needed in multiple flexible content layouts | Clone |
| Large number of layouts (10+) in flexible content | Clone + separate field groups |
| Simple page with 2-3 known layouts | Inline flexible content layouts |
| Component used across different field types (repeater, group, flex) | Clone |

### Organizing Field Groups

1. **One field group per context**: Rather than one giant field group for all page fields,
   create separate groups for "Hero Section", "Content Sections", "SEO Settings", etc.

2. **Use `menu_order` to control display order**: Lower numbers appear first.

3. **Use Tab and Accordion fields** to organize related fields visually within a group.

4. **Keep field groups focused**: A field group with 50+ fields is hard to maintain. Break it
   into multiple groups with specific location rules.

5. **Naming convention for field groups**: Use a consistent prefix to categorize:
   - "Page: Landing Page Hero"
   - "Block: Testimonial Card"
   - "Component: Button Settings"
   - "Options: Theme Settings"
   - "Layout: Hero Banner"

### Performance Considerations

1. **Use Local JSON**: Loading from JSON files is approximately 50% faster than database
   queries. Always maintain an `acf-json/` directory.

2. **Return format optimization**: For `image` and `file` fields, use `"return_format": "id"`
   whenever possible. ACF must build full array/URL objects from the ID, so returning the
   ID alone is significantly faster, especially with many image fields.

3. **Break up large field groups**: Multiple smaller groups load more efficiently than one
   massive group and are easier to maintain.

4. **Repeater pagination**: For repeaters that may have many rows (20+), enable pagination
   with `"pagination": 1` and set `"rows_per_page"` to a reasonable number.

5. **Avoid deeply nested structures**: Repeaters inside repeaters inside flexible content
   layouts create exponential database queries. Limit nesting to 2-3 levels maximum.

6. **Autoload Options Pages**: For options page fields accessed on every page load (header,
   footer, site settings), enable "Autoload" on the options page definition so values are
   loaded with WordPress's initial option loading.

### Location Rules

1. **Be specific**: Rather than showing a field group on all pages, target specific templates
   or post types.

2. **Use AND rules for precision**: Combine `post_type` + `page_template` to target exactly
   the right edit screen.

3. **Avoid overlapping rules**: If two field groups target the same location, both will
   appear. Use `menu_order` to control which appears first.

---

## Appendix: Minimal Complete Example

A minimal but valid ACF JSON field group file:

```json
{
    "key": "group_example_hero",
    "title": "Hero Section",
    "fields": [
        {
            "key": "field_example_hero_heading",
            "label": "Heading",
            "name": "hero_heading",
            "type": "text",
            "required": 1
        },
        {
            "key": "field_example_hero_subheading",
            "label": "Subheading",
            "name": "hero_subheading",
            "type": "textarea",
            "rows": 3,
            "new_lines": "br"
        },
        {
            "key": "field_example_hero_bg",
            "label": "Background Image",
            "name": "hero_background_image",
            "type": "image",
            "return_format": "id",
            "preview_size": "medium",
            "required": 1
        },
        {
            "key": "field_example_hero_overlay",
            "label": "Show Overlay",
            "name": "hero_show_overlay",
            "type": "true_false",
            "default_value": 1,
            "ui": 1
        },
        {
            "key": "field_example_hero_overlay_color",
            "label": "Overlay Color",
            "name": "hero_overlay_color",
            "type": "color_picker",
            "default_value": "#000000",
            "conditional_logic": [
                [
                    {
                        "field": "field_example_hero_overlay",
                        "operator": "==",
                        "value": "1"
                    }
                ]
            ]
        }
    ],
    "location": [
        [
            {
                "param": "post_type",
                "operator": "==",
                "value": "page"
            },
            {
                "param": "page_template",
                "operator": "==",
                "value": "templates/landing.php"
            }
        ]
    ],
    "menu_order": 0,
    "position": "acf_after_title",
    "style": "seamless",
    "label_placement": "top",
    "instruction_placement": "label",
    "hide_on_screen": "",
    "active": 1,
    "description": "Hero section fields for landing pages.",
    "show_in_rest": 0,
    "modified": 1700000000
}
```
