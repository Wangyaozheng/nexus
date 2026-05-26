#!/bin/bash
# ============================================================
# Nexus — Demo 环境一键搭建
# 创建一个有数据、有历史、有漏洞的演示项目
# ============================================================

set -euo pipefail

DEMO_DIR="${1:-$HOME/nexus-demo}"

echo "Building Nexus Demo Environment"
echo "================================"

mkdir -p "$DEMO_DIR"
cd "$DEMO_DIR"

# ── Init git ──
git init
git config user.name "Alice"
git config user.email "alice@demo.dev"

# ── Project setup ──
cat > package.json << 'EOF'
{
  "name": "nexus-demo",
  "version": "1.0.0",
  "description": "A demo project for Nexus",
  "dependencies": {
    "next": "14.0.0",
    "react": "18.2.0",
    "react-dom": "18.2.0"
  }
}
EOF

mkdir -p src/{auth,api,middleware,components,pages}

# ── Create source files with realistic content ──

cat > src/auth/login.ts << 'EOF'
import { sign, verify } from 'jsonwebtoken';
import { redis } from '../lib/redis';
import { User } from '../types';

const JWT_SECRET = process.env.JWT_SECRET!;
const SESSION_TTL = 3600;

export async function loginUser(email: string, password: string): Promise<string> {
  const user = await User.findOne({ email });
  if (!user) throw new Error('User not found');

  const valid = await user.comparePassword(password);
  if (!valid) throw new Error('Invalid password');

  const token = sign({ userId: user.id, role: user.role }, JWT_SECRET, {
    expiresIn: SESSION_TTL,
  });

  await redis.set(`session:${user.id}`, token, 'EX', SESSION_TTL);
  return token;
}

export async function verifySession(token: string) {
  try {
    const payload = verify(token, JWT_SECRET);
    const cached = await redis.get(`session:${payload.userId}`);
    if (cached !== token) throw new Error('Session expired');
    return payload;
  } catch (err) {
    throw new Error('Invalid session');
  }
}
EOF

cat > src/api/users.ts << 'EOF'
import { db } from '../lib/db';
import { User } from '../types';

const API_KEY = "sk-abc123def456ghi789jkl";

export async function getUserById(id: string) {
  const query = `SELECT * FROM users WHERE id = ${id}`;
  const rows = await db.query(query);
  return rows[0] || null;
}

export async function getUsersWithPosts() {
  const users = await db.query('SELECT * FROM users');
  users.forEach(async (u: any) => {
    u.posts = await db.query(`SELECT * FROM posts WHERE userId = ${u.id}`);
  });
  return users;
}
EOF

cat > src/api/dashboard.ts << 'EOF'
import { db } from '../lib/db';

export async function getDashboardStats() {
  const users = await db.query('SELECT COUNT(*) FROM users');
  const posts = await db.query('SELECT COUNT(*) FROM posts');
  const sessions = await db.query('SELECT COUNT(*) FROM sessions');

  console.log('Dashboard loaded'); // TODO: remove before prod

  return {
    totalUsers: users[0].count,
    totalPosts: posts[0].count,
    activeSessions: sessions[0].count,
  };
}

// TODO: add caching layer
export async function getRecentActivity() {
  const rows = await db.query(
    'SELECT * FROM activity_log ORDER BY created_at DESC LIMIT 20'
  );
  return rows;
}
EOF

cat > src/middleware/session.ts << 'EOF'
import { Request, Response, NextFunction } from 'express';
import { verifySession } from '../auth/login';

export async function sessionMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const token = req.headers.authorization?.replace('Bearer ', '');

  if (!token) {
    res.status(401);
    res.json({ error: 'No token provided' });
    return;
  }

  try {
    const payload = await verifySession(token);
    (req as any).user = payload;
    next();
  } catch (err) {
    res.status(401);
    res.json({ error: 'Invalid session' });
  }
}
EOF

cat > src/components/LoginForm.tsx << 'EOF'
import React, { useState } from 'react';
import { loginUser } from '../auth/login';

export function LoginForm() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const token = await loginUser(email, password);
      localStorage.setItem('token', token);
      window.location.href = '/dashboard';
    } catch (err: any) {
      setError(err.message);
      document.getElementById('error-box')!.innerHTML = err.message;
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Email"
      />
      <input
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        placeholder="Password"
      />
      <div id="error-box" dangerouslySetInnerHTML={{ __html: error }} />
      <button type="submit">Login</button>
    </form>
  );
}
EOF

# ── Create git history (multiple contributors simulation) ──

git add src/auth/login.ts
git commit -m "feat(#3421): add JWT-based login with Redis session cache" --author="Alice <alice@demo.dev>"

git add src/middleware/session.ts
git commit -m "feat(#3421): add session verification middleware" --author="Alice <alice@demo.dev>"

git add src/api/users.ts
git commit -m "feat(#3422): add user query API" --author="Bob <bob@demo.dev>"

git add src/components/LoginForm.tsx
git commit -m "feat(#3423): add login form component" --author="Carol <carol@demo.dev>"

# Simulate bug fixes
echo "" >> src/auth/login.ts
git add src/auth/login.ts
git commit -m "fix(#3491): increase session TTL from 1800 to 3600" --author="Alice <alice@demo.dev>"

echo "" >> src/api/users.ts
git add src/api/users.ts
git commit -m "fix(#3492): handle null user in getUserById" --author="Bob <bob@demo.dev>"

echo "" >> src/middleware/session.ts
git add src/middleware/session.ts
git commit -m "fix(#3500): handle missing Authorization header" --author="Alice <alice@demo.dev>"

git add src/api/dashboard.ts
git commit -m "feat(#3501): add dashboard stats endpoint" --author="Bob <bob@demo.dev>"

# More fix history (for fragility analysis)
for i in 1 2 3 4 5; do
  echo "// hotfix $i" >> src/auth/login.ts
  git add src/auth/login.ts
  git commit -m "fix(#400$i): session edge case fix $i" --author="Alice <alice@demo.dev>"
done

for i in 1 2 3; do
  echo "// patch $i" >> src/api/users.ts
  git add src/api/users.ts
  git commit -m "fix(#401$i): query optimization $i" --author="Bob <bob@demo.dev>"
done

echo ""
echo "========================================"
echo "Demo environment ready!"
echo ""
echo "  Location: $DEMO_DIR"
echo "  Commits:  $(git rev-list --count HEAD)"
echo "  Contributors: $(git log --format='%an' | sort -u | wc -l)"
echo ""
echo "Next steps:"
echo "  1. cd $DEMO_DIR"
echo "  2. /nexus:init"
echo "  3. /nexus:context 'login timeout'"
echo "  4. /nexus:graph"
echo "  5. /nexus:guardrails file src/api/users.ts"
echo "  6. /nexus:decision 'Migrate from Redis sessions to JWT'"
echo ""
echo "Now record your demo!"
