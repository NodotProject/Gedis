---
layout: post
title: Code Highlighting and Styling
tags: tutorial open-source
---

Code highlighting and styling is based on [highlight.js](https://highlightjs.org/) and TailwindCSS customization.

Some examples:

```
git clone https://github.com/harrywang/tailpages.git
cd tailpages
```
...

To enable typography plugin, inter font, and customizations by updating `tailwid.config.js` as follows:

```js
const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './**/*.html'
  ],
  darkMode: 'media',
  theme: {
    extend: {
      typography: {
        DEFAULT: {
          css: {
            pre: {
              padding: "0",
              color: "#1F2933",
              backgroundColor: "#F3F3F3"
            },
            code: {
              padding: "0.2em 0.4em",
              backgroundColor: "#F3F3F3",
              color: "#DD1144",
              fontWeight: "400",
              "border-radius": "0.25rem"
            },
            "code::before": false,
            "code::after": false,
            "blockquote p:first-of-type::before": false,
            "blockquote p:last-of-type::after": false,
          },
        },
      },
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
    },
  },

  variants: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/typography'),
  ],

}
```

See more examples at [here](https://harrywang.me/2022/01/18/tailpages-tutorial-technical.html)
