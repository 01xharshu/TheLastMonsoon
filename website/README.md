# The Last Monsoon — website

Standalone official website built with Next.js App Router, TypeScript, Tailwind CSS, and Motion. All web dependencies and configuration live here; the parent Godot project is not required to build or deploy it. `.gdignore` prevents Godot from scanning this directory. There is no nested Git repository.

## Local development

Use Node.js 22 or newer (Node.js 24 LTS recommended).

```sh
cd website
npm ci
npm run dev
```

Visit http://localhost:3000. Validate with `npm run typecheck` and `npm run build`; serve the production build with `npm start`.

## Vercel

Import the existing GitHub repository into Vercel, set **Root Directory** to `website`, and select the **Next.js** framework preset. Use `npm ci` to install and `npm run build` to build. Leave the output directory at its framework default. No access to files outside the Root Directory is necessary.

Set `NEXT_PUBLIC_SITE_URL` to the final HTTPS public origin, without a trailing slash, before the production build. It controls canonical URLs, Open Graph URLs, robots, and sitemap. If omitted, the app uses Vercel's production domain when available, otherwise localhost. The example domain in `.env.example` must be replaced. Production publication has not been performed by this implementation.

## Publishing journal entries

Add a `.md` file to `content/journal/`; its filename becomes `/journal/<filename-without-extension>`. Dates are quoted ISO dates. Required frontmatter:

```yaml
---
title: "Your update title"
date: "2026-10-08"
description: "A concise description of verified work."
category: "World"
image: "/media/your-image.webp"
status: "In development"
placeholder: false
---
```

Put the image in `public/media/`. Status must be `Concept`, `In development`, or `Update`. Content is standard Markdown with GitHub-style tables and lists; HTML is not executed. Entries are validated at build time, ordered newest first, rendered as static article pages, and added to the sitemap automatically. Category filters derive from frontmatter. Sample entries have `placeholder: true`, which displays a warning. Replace the sample entries before announcing real progress. Changes require a new build/deployment. No database or external API is used.

## Media and reusable components

The three current WebP landscape studies are AI-generated website-only concept placeholders, not approved game media or historically verified reconstructions. They were generated using the built-in ImageGen tool and optimized locally. Generation briefs and reference observations are recorded in `ART_DIRECTION.md`; final assets live in `public/media/`. The gallery in `src/components/gallery.tsx` supports local screenshots and artwork: add a path, descriptive alt text, title, and type to its `media` collection; remove placeholder wording only for real approved media. Replace the hero/world artwork in `src/app/page.tsx` with approved images when available. Use WebP/AVIF images at appropriate resolutions; Next Image optimizes raster images, lazily loads below-fold media, and preloads only the hero. The locally served Cormorant Garamond display font is packaged through Fontsource; its license is included with the installed package.

Navigation, section titles, journal cards, gallery, footer, and Motion reveal wrappers are reusable components. The gallery uses a native modal dialog for focus containment, Escape dismissal, and focus restoration. The cinematic motion system uses Motion scroll values for hero parallax, desktop sticky world chapters with image/caption depth, staggered section reveals, and gallery crossfades. The hero title/copy entrance, subtle rain, scroll cue, and hover feedback use CSS keyframes/transitions. Scrolling remains native. Desktop chapters pin for a short passage; mobile chapters remain compact. Motion honors system reduced motion; content remains visible without animation or JavaScript. A persistent Pause motion control also disables movement and stores the optional preference locally. The gallery supports arrow keys and horizontal swipe, while retaining native dialog focus behavior. No autoplay video, remote fonts, analytics, or third-party runtime media requests are required.

## Verification

Run `npm run typecheck` and `npm run build`. Then check home, `/journal`, all article links, `/sitemap.xml`, `/robots.txt`, `/opengraph-image`, and an unknown article URL (404). At a narrow viewport, check the Menu toggle, anchor navigation, category buttons, and gallery. Navigate the gallery with keyboard, close it with Escape, and confirm focus returns to its opener. Enable reduced motion in system settings and verify content remains visible.

No test captures or reports should be retained. Browser appearance checks supplement the production build; they do not approve actual game assets or substantiate the example journal claims.

## Motion verification

Run the production server, then reload home and watch the roughly two-second title/copy entrance. Scroll slowly: the hero image and copy move at different rates. On desktop, scroll through each world chapter: the panel pins, the artwork changes scale/depth, captions settle, and the gold progress line advances. At 390px, chapters remain ordinary 550px sections. The header compacts after scrolling, and Menu closes with Escape while returning focus to its toggle.

Open the gallery and use Next/Previous or arrow keys to check its crossfade. On touch hardware, swipe horizontally; vertical gestures remain available. Escape must close the dialog, restore body scrolling, and return focus to the opener. Click Pause motion: rain/parallax/reveals stop, hero text stays visible, and desktop chapters return to static sections. Reload to confirm the pause preference persists, then re-enable it. Enable your system's reduced-motion preference: animation must remain off and the motion control must report that system setting.

Current verification: production build and TypeScript passed; desktop and 390px browser checks covered scroll-linked transform changes, sticky position, pause fallback, gallery arrow-key navigation/Escape/focus restoration, scroll-lock cleanup, menu Escape, and horizontal overflow. No browser warnings/errors were observed. System reduced-motion behavior was reviewed in code; a physical device performance and system-setting check remains open. No screenshots, videos, logs, or generated test reports are retained.

The opening now includes a coordinated three-panel landscape montage: on desktop it pins briefly, the artwork expands and dissolves into the full landscape, and the centered title recedes. An additional story statement brightens word by word with scrolling; chapter inset studies reveal through a mask on a separate motion track. On mobile, the opening does not pin. To verify the refinement, reload home, scroll in small increments through the opening and statement, then inspect chapter insets. Pause midway and confirm all text is fully opaque and inset images are unclipped; reload to verify that the saved pause preference is applied before animation begins. Keyboard-focused hero actions remain visible during the scroll dissolve.
