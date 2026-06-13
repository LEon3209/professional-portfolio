document.addEventListener('DOMContentLoaded', () => {
  const grid = document.getElementById('card-grid');
  const filterBar = document.getElementById('filter-bar');
  const CATEGORIES = ['Data & Analytics', 'Thesis', 'Strategy & Business', 'Finance', 'Media & Communication'];
  const FEATURED_TITLES = [
    'Amazon Prime Video Dashboard',
    'IBM HR Analytics Dashboard',
    'Engaging Key Stakeholders for School Connectivity in Ethiopia',
    'Portfolio Optimization & Financial Analysis',
    'Genre-Based Music Recommendation System',
    'UNIGE Instagram Takeover',
  ];
  let projects = [];
  let activeCategory = null; // null = featured, 'all' = all, string = category

  function init(data) {
    projects = data.filter(p => !p.hidden).sort((a, b) => new Date(b.date) - new Date(a.date));
    renderFilters();
    renderCards();
    observeReveals();
  }

  if (grid) {
    if (Array.isArray(window.PROJECTS)) {
      init(window.PROJECTS);
    } else {
      fetch('projects.json')
        .then(res => res.json())
        .then(init)
        .catch(() => {
          grid.innerHTML = '<div class="card"><p>Project index unavailable.</p></div>';
        });
    }
  }

  function renderFilters() {
    filterBar.innerHTML = '';
    addFilterBtn('Featured', null, true);
    CATEGORIES.forEach(cat => addFilterBtn(cat, cat, false));
    addFilterBtn('All', 'all', false);
  }

  function addFilterBtn(label, cat, isActive) {
    const btn = document.createElement('button');
    btn.className = 'filter-btn' + (isActive ? ' active' : '');
    btn.textContent = label;
    btn.addEventListener('click', () => {
      activeCategory = cat;
      filterBar.querySelectorAll('.filter-btn').forEach(b => {
        b.classList.toggle('active', b.textContent === label);
      });
      renderCards();
    });
    filterBar.appendChild(btn);
  }

  function slugify(t) {
    return t.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
  }

  function renderCard(project) {
    const tagsHTML = project.tags.map(t => `<span class="tag">${t}</span>`).join('');
    const date = new Date(project.date).toLocaleDateString('en-US', { year: 'numeric', month: 'short' });
    const cover = project.image || `projects/covers/${slugify(project.title)}.svg`;

    let href = '#';
    let cta = 'View →';
    let attrs = '';
    if (project.page) {
      href = project.page;
      cta = 'View Project →';
    } else if (project.file) {
      const isDoc = /\.(zip|xlsx|pptx|ipynb)$/i.test(project.file);
      href = encodeURI(project.file);
      cta = isDoc ? 'Download ↓' : 'Open ↗';
      attrs = isDoc ? 'download' : 'target="_blank" rel="noopener"';
    } else if (project.url) {
      href = project.url;
      cta = 'View →';
      attrs = 'target="_blank" rel="noopener"';
    }

    return `
      <a class="card" href="${href}" ${attrs}>
        <div class="card-cover">
          <img src="${cover}" alt="" loading="lazy">
        </div>
        <div class="card-body">
          <h3>${project.title}</h3>
          <p>${project.description}</p>
          <div class="card-tags">${tagsHTML}</div>
          <div class="card-footer">
            <span class="card-date">${date}</span>
            <span class="card-cta">${cta}</span>
          </div>
        </div>
      </a>`;
  }

  function renderCards() {
    if (activeCategory === 'all') {
      // Show all, grouped by category with headers
      grid.innerHTML = CATEGORIES.map(cat => {
        const catProjects = projects.filter(p => p.category === cat);
        if (!catProjects.length) return '';
        return `
          <div class="cat-header">${cat}</div>
          ${catProjects.map(renderCard).join('')}`;
      }).join('');
    } else if (activeCategory) {
      const filtered = projects.filter(p => p.category === activeCategory);
      grid.innerHTML = filtered.map(renderCard).join('');
    } else {
      // Featured: show projects in the specified order
      const featured = FEATURED_TITLES
        .map(title => projects.find(p => p.title === title))
        .filter(Boolean);
      grid.innerHTML = featured.map(renderCard).join('');
    }
    observeReveals();
  }

  /* ---------- reveal-on-scroll ---------- */
  function observeReveals() {
    const els = document.querySelectorAll('.reveal:not(.in-view)');
    if (!('IntersectionObserver' in window)) {
      els.forEach(el => el.classList.add('in-view'));
      return;
    }
    const io = new IntersectionObserver((entries) => {
      entries.forEach(e => {
        if (e.isIntersecting) { e.target.classList.add('in-view'); io.unobserve(e.target); }
      });
      // a fixed ratio threshold never fires for elements taller than the
      // viewport (e.g. the project grid), so trigger on any intersection
    }, { threshold: 0, rootMargin: '0px 0px -40px 0px' });
    els.forEach(el => io.observe(el));
  }
  observeReveals();

  /* ---------- scroll-spy nav ---------- */
  const sections = document.querySelectorAll('section[id], header[id]');
  const navLinks = document.querySelectorAll('.nav-links a');
  if (sections.length && 'IntersectionObserver' in window) {
    const spy = new IntersectionObserver((entries) => {
      entries.forEach(e => {
        if (e.isIntersecting) {
          const id = e.target.id;
          navLinks.forEach(a => a.classList.toggle('active', a.getAttribute('href') === '#' + id));
        }
      });
    }, { rootMargin: '-45% 0px -50% 0px' });
    sections.forEach(s => spy.observe(s));
  }
});
