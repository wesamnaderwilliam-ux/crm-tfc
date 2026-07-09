# Landing Page Generator Skill

This skill enables the generation of fully parametrizable static landing pages using HTML and CSS.

## Parameters

The skill accepts the following parameters:

- `title` (string): Main title of the landing page (required)
- `subtitle` (string): Subtitle or tagline (optional)
- `description` (string): Main description/content (optional)
- `primary_color` (string): Primary color in hex format (default: #3B82F6)
- `secondary_color` (string): Secondary color in hex format (default: #1D4ED8)
- `background_color` (string): Background color (default: #F8FAFC)
- `text_color` (string): Text color (default: #1E293B)
- `font_family` (string): Font family (default: system-ui, sans-serif)
- `sections` (array): Array of section objects to include (optional)
  - Each section can have:
    - `type`: "hero", "features", "testimonials", "cta", "custom"
    - `content`: Section-specific content
    - `background`: Override background color for this section
    - `text_color`: Override text color for this section

## Usage

When this skill is loaded, the AI can generate landing pages by following these instructions:

1. Collect all required parameters from the user
2. Validate parameters (ensure title is provided, colors are valid hex, etc.)
3. Generate HTML5 document with embedded CSS
4. Apply the color scheme and typography
5. Structure content according to requested sections
6. Output complete, valid HTML file

## Generation Process

The AI should:
1. Start with `<!DOCTYPE html>` and basic HTML structure
2. Create a `<style>` tag with CSS variables for easy theming
3. Define CSS classes for layout (container, sections, etc.)
4. Generate responsive design using CSS Flexbox/Grid
5. Include meta tags for viewport and charset
6. Structure content based on section types:
   - Hero: Large title, subtitle, call-to-action button
   - Features: Icon/list of key features
   - Testimonials: Quote/customer feedback area
   - CTA: Prominent button/link section
   - Custom: Raw HTML content provided by user
7. Ensure accessibility (semantic HTML, aria labels, contrast ratios)
8. Output only the HTML code (no additional explanations)

## Example Invocation

After loading this skill, the user might say:
"Generate a landing page with title 'My Awesome Product', subtitle 'The best solution for your needs', primary color '#10B981', and sections: hero and features."

The AI would then generate the complete HTML landing page based on these parameters.