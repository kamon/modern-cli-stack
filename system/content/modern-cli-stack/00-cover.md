---
title: "{{ product.title }}"
subtitle: "{{ product.subtitle }}"
author: "{{ author.name }}"
date: "{{ now().strftime('%Y-%m-%d') }}"
version: "{{ product.version }}"
titlepage: true
titlepage-color: "FFFFFF"
titlepage-text-color: "1A1A1A"
titlepage-rule-color: "ForestGreen"
titlepage-rule-height: 2
---

# {{ product.title }}

## {{ product.subtitle }}

**{{ product.tagline }}**

---

**By {{ author.name }}** · [@{{ author.handle }}]({{ social.twitter }})

**Edition:** v{{ product.version }} · {{ product.audience.platforms | join(' · ') }}

**License:** {{ author.defaults.license }}

[Companion newsletter]({{ links.newsletter }}) · [Follow on X]({{ links.twitter }}) · [Buy me a coffee]({{ links.coffee }})

\newpage