/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/models/**/*.rb', // 📖 Ensure models are scanned
    './app/javascript/**/*.js'
  ],
  safelist: [
    'trix-content',
    'trix-content h1',
    'trix-content h2',
    'trix-content h3',
    'trix-content p',
    'trix-content a',
    'trix-content blockquote',
    'trix-content pre',
    'trix-content ul',
    'trix-content ol',
    'trix-content li',
    'trix-content strong',
    'trix-content em'
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('daisyui'),
  ],
  daisyui: {
    themes: true,
  }
}

