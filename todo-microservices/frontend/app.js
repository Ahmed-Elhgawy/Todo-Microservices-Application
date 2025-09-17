const API = "/api";

async function fetchTodos() {
  const res = await fetch(`${API}/todos`);
  return res.json();
}

function renderTodos(todos) {
  const el = document.getElementById('todos');
  el.innerHTML = '';
  todos.forEach(t => {
    const div = document.createElement('div');
    div.className = 'todo';
    div.innerHTML = `
      <div class="left">
        <h3>${t.title} ${t.done ? '✓' : ''}</h3>
        <p>${t.description || ''}</p>
      </div>
      <div class="actions">
        <button class="btn ok" data-id="${t.id}" data-action="toggle">${t.done ? 'Undone' : 'Done'}</button>
        <button class="btn danger" data-id="${t.id}" data-action="delete">Delete</button>
      </div>
    `;
    el.appendChild(div);
  });
}

async function loadAndRender() {
  const todos = await fetchTodos();
  renderTodos(todos);
}

document.getElementById('todo-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const title = document.getElementById('title').value.trim();
  const description = document.getElementById('description').value.trim();
  if (!title) return alert('Title required');
  await fetch(`${API}/todos`, {
    method: 'POST',
    headers: {'Content-Type':'application/json'},
    body: JSON.stringify({ title, description })
  });
  document.getElementById('title').value = '';
  document.getElementById('description').value = '';
  await loadAndRender();
});

document.getElementById('todos').addEventListener('click', async (e) => {
  const btn = e.target.closest('button');
  if (!btn) return;
  const id = btn.dataset.id;
  const action = btn.dataset.action;
  if (action === 'toggle') {
    // fetch current then update
    const res = await fetch(`${API}/todos/${id}`);
    const todo = await res.json();
    await fetch(`${API}/todos/${id}`, {
      method: 'PUT',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({ title: todo.title, description: todo.description, done: !todo.done })
    });
    await loadAndRender();
  } else if (action === 'delete') {
    if (!confirm('Delete todo?')) return;
    await fetch(`${API}/todos/${id}`, { method: 'DELETE' });
    await loadAndRender();
  }
});

// initial
loadAndRender();
