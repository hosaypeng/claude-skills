# Slide Deck CSS Foundation and JS Navigation

## CSS Foundation

```css
* { margin: 0; padding: 0; box-sizing: border-box; }
:root {
  --bg: #1a1a2e;
  --text: #e0e0e0;
  --accent: #4fc3f7;
  --card-bg: #16213e;
  --border: #0f3460;
}
[data-theme="light"] {
  --bg: #fafafa;
  --text: #1a1a2e;
  --accent: #0277bd;
  --card-bg: #ffffff;
  --border: #e0e0e0;
}
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
  background: var(--bg);
  color: var(--text);
  overflow: hidden;
  height: 100vh;
}
```

## JS Slide Navigation

```javascript
const slides = document.querySelectorAll('.slide');
let current = 0;

function showSlide(n) {
  slides.forEach(s => s.classList.remove('active'));
  current = Math.max(0, Math.min(n, slides.length - 1));
  slides[current].classList.add('active');
  document.getElementById('progress').textContent = `${current + 1} / ${slides.length}`;
}

document.addEventListener('keydown', e => {
  if (e.key === 'ArrowRight' || e.key === ' ') showSlide(current + 1);
  if (e.key === 'ArrowLeft') showSlide(current - 1);
});

showSlide(0);
```

## Diagram Guidelines

Since no external libraries are allowed, build all diagrams with CSS:

- **Boxes**: `div` elements with border, border-radius, padding
- **Arrows**: CSS pseudo-elements (`::after`) with borders rotated 45deg, or Unicode arrows (-> |)
- **Flow lines**: Thin divs with background color connecting boxes
- **Layout**: Flexbox or CSS Grid for positioning
- **Colors**: Use `var(--accent)` for highlights, `var(--border)` for connectors
