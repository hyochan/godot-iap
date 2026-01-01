import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'Godot IAP',
  tagline: 'In-App Purchase solution for Godot Engine',
  favicon: 'img/favicon.png',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  url: 'https://hyochan.github.io',
  baseUrl: '/godot-iap/',

  // GitHub pages deployment config.
  organizationName: 'hyochan', // Usually your GitHub org/user name.
  projectName: 'godot-iap', // Usually your repo name.

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl: 'https://github.com/hyochan/godot-iap/tree/main/docs/',
          lastVersion: 'current',
          versions: {
            current: {
              label: '1.0 (Current)',
              path: '',
            },
          },
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themes: [
    [
      require.resolve('@easyops-cn/docusaurus-search-local'),
      {
        hashed: true,
        language: ['en'],
        indexDocs: true,
        indexBlog: false,
        indexPages: false,
        docsRouteBasePath: '/',
        highlightSearchTermsOnTargetPage: true,
        searchResultLimits: 8,
        searchBarShortcutHint: true,
      },
    ],
  ],

  themeConfig: {
    // Replace with your project's social card
    image: 'img/icon.png',
    navbar: {
      title: 'Godot IAP',
      logo: {
        alt: 'Godot IAP Logo',
        src: 'img/icon.png',
        width: 32,
        height: 32,
      },
      items: [
        {
          type: 'docsVersionDropdown',
          position: 'left',
          dropdownActiveClassDisabled: true,
        },
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Docs',
        },
        {
          href: 'https://github.com/hyochan/godot-iap',
          label: 'GitHub',
          position: 'right',
        },
        {
          href: 'https://openiap.dev',
          label: 'OpenIAP',
          position: 'right',
        },
        {
          href: 'https://x.com/hyodotdev',
          label: 'X',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Getting Started',
              to: '/',
            },
            {
              label: 'API Reference',
              to: '/api',
            },
            {
              label: 'Examples',
              to: '/examples/purchase-flow',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'GitHub Issues',
              href: 'https://github.com/hyochan/godot-iap/issues',
            },
            {
              label: 'Godot Asset Library',
              href: 'https://godotengine.org/asset-library/asset',
            },
            {
              label: 'Slack',
              href: 'https://hyo.dev/joinSlack',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'OpenIAP Specification',
              href: 'https://openiap.dev',
            },
            {
              label: 'GitHub',
              href: 'https://github.com/hyochan/godot-iap',
            },
            {
              label: 'Godot Documentation',
              href: 'https://docs.godotengine.org',
            },
          ],
        },
        {
          title: 'Social',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/hyochan',
            },
            {
              label: 'LinkedIn',
              href: 'https://linkedin.com/in/hyochanjang',
            },
            {
              label: 'X',
              href: 'https://x.com/hyodotdev',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} hyochan.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['gdscript', 'kotlin', 'swift', 'json', 'bash'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
