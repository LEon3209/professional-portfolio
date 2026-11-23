document.addEventListener('DOMContentLoaded', () => {
  /* ---------- selected work ---------- */
  const rows = document.getElementById('work-rows');
  const filters = document.getElementById('filters');
  const count = document.getElementById('work-count');

  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));

  let showFilter = () => {};

  function init(data) {
    const visible = data.filter((p) => !p.hidden);
    // rows are newest first; category order follows projects.json
    const projects = [...visible].sort((a, b) => b.date.localeCompare(a.date));
    const featured = projects.filter((p) => p.featured);
    const views = [
      ...(featured.length ? [['Featured', featured]] : []),
      ['All', projects],
      ...[...new Set(visible.map((p) => p.category))].map((c) => [c, projects.filter((p) => p.category === c)]),
    ];

    const buttons = views.map(([label, list], i) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.textContent = label;
      btn.setAttribute('aria-pressed', String(i === 0));
      btn.addEventListener('click', () => showFilter(label));
      filters.appendChild(btn);
      return [label, btn, list];
    });

    showFilter = (label) => {
      buttons.forEach(([l, btn, list]) => {
        btn.setAttribute('aria-pressed', String(l === label));
        if (l === label) render(list, l === 'Featured' ? projects.length : 0);
      });
    };

    showFilter(views[0][0]);
  }

  function render(list, total) {
    count.textContent = `(${String(list.length).padStart(2, '0')})`;
    if (!list.length) {
      rows.innerHTML = '<p class="work-empty muted">No projects in this category yet.</p>';
      return;
    }
    rows.innerHTML = list.map((p) => {
      const href = esc(p.page);
      const title = esc(p.title);
      const tags = (p.tags || []).map((t) => `<span>${esc(t)}</span>`).join('');
      return `
        <article class="work-row">
          <div>
            <div class="work-row__meta label"><span>${esc(p.category)}</span><span>${esc(p.date.slice(0, 4))}</span></div>
            <h3>${title}</h3>
            <p class="work-row__desc">${esc(p.description)}</p>
            <a class="work-row__more" href="${href}">Read more<span class="sr-only"> about ${title}</span></a>
          </div>
          <a class="plate" href="${href}" tabindex="-1" aria-hidden="true">
            <img src="${esc(p.preview || p.image)}" alt="" loading="lazy" decoding="async">
            <span class="plate__tags">${tags}</span>
          </a>
        </article>`;
    }).join('') + (total ? `
      <div class="work-all">
        <button type="button" class="btn">See all ${total} projects <span aria-hidden="true">→</span></button>
      </div>` : '');

    const all = rows.querySelector('.work-all button');
    if (all) {
      all.addEventListener('click', () => {
        showFilter('All');
        filters.querySelector('button[aria-pressed="true"]').focus();
      });
    }
  }

  if (rows && filters && count) {
    if (Array.isArray(window.PROJECTS)) {
      init(window.PROJECTS);
    } else {
      fetch('projects.json')
        .then((res) => res.json())
        .then(init)
        .catch(() => { rows.innerHTML = '<p class="work-empty muted">Project list unavailable.</p>'; });
    }
  }

  /* ---------- nav: shrink on scroll + current section ---------- */
  const nav = document.querySelector('.site-nav');
  if (!nav) return;

  const links = [...nav.querySelectorAll('.site-nav__links a')];
  const sections = links
    .map((a) => document.querySelector(a.getAttribute('href')))
    .filter(Boolean);

  function update() {
    nav.classList.toggle('is-mini', window.scrollY > 80);

    let current = null;
    sections.forEach((s) => { if (s.getBoundingClientRect().top < 200) current = s.id; });
    // the last section can be too short to reach the line: treat page bottom as "contact"
    if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 2) {
      current = sections[sections.length - 1].id;
    }
    links.forEach((a) => {
      const on = a.getAttribute('href') === `#${current}`;
      a.classList.toggle('is-active', on);
      if (on) a.setAttribute('aria-current', 'location');
      else a.removeAttribute('aria-current');
    });
  }

  let ticking = false;
  window.addEventListener('scroll', () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => { update(); ticking = false; });
  }, { passive: true });
  update();
});
