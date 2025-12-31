import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.
 */
const sidebars: SidebarsConfig = {
  // Manual sidebar configuration for godot-iap documentation
  tutorialSidebar: [
    {
      type: 'doc',
      id: 'index',
      label: 'Introduction',
    },
    {
      type: 'category',
      label: 'Getting Started',
      items: [
        'getting-started/installation',
        'getting-started/setup-ios',
        'getting-started/setup-android',
      ],
    },
    {
      type: 'category',
      label: 'Guides',
      items: [
        'guides/lifecycle',
        'guides/purchases',
        'guides/subscription-offers',
        'guides/error-handling',
        'guides/troubleshooting',
      ],
    },
    {
      type: 'category',
      label: 'API Reference',
      link: {
        type: 'doc',
        id: 'api/index',
      },
      items: [
        {
          type: 'category',
          label: 'Methods',
          link: {type: 'doc', id: 'api/methods/core-methods'},
          items: [
            'api/methods/unified-apis',
            'api/methods/listeners',
            'api/methods/ios-specific',
            'api/methods/android-specific',
          ],
        },
      ],
    },
    {
      type: 'category',
      label: 'Examples',
      items: [
        'examples/purchase-flow',
        'examples/subscription-flow',
        'examples/available-purchases',
      ],
    },
    {
      type: 'doc',
      id: 'sponsors',
      label: 'Sponsors',
    },
  ],
};

export default sidebars;
