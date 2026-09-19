const fs = require('fs');
const path = 'C:\\NetworkMaintenance\\Dashboard\\library\\librarian-dashboard.html';

const content = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>\u0644\u0648\u062d\u0629 \u0623\u0645\u064a\u0646 \u0627\u0644\u0645\u0643\u062a\u0628\u0629 - \u0645\u0643\u062a\u0628\u0629 \u0627\u0644\u062d\u0633\u064a\u0646\u064a</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/core@1.0.0-beta17/dist/css/tabler.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@3.6.0/tabler-icons.min.css">
    <style>
        :root{--primary:#1a365d;--accent:#3182ce;--bg:#f1f5f9}
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:'Segoe UI',Tahoma,sans-serif;background:var(--bg);direction:rtl}
        .sidebar{width:250px;background:var(--primary);color:#fff;position:fixed;height:100vh;overflow-y:auto;z-index:100}
        .sidebar-brand{padding:1.25rem;font-size:1.2rem;font-weight:700;border-bottom:1px solid rgba(255,255,255,0.1);display:flex;align-items:center;gap:.5rem}
        .sidebar .nav-link{color:rgba(255,255,255,0.7);padding:.7rem 1.2rem;display:flex;align-items:center;gap:.6rem;text-decoration:none;transition:all .2s}
        .sidebar .nav-link:hover,.sidebar .nav-link.active{background:rgba(255,255,255,0.1);color:#fff;border-radius:8px;margin:2px 8px}
        .main-content{margin-right:250px;padding:1.5rem}
        .page-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:1.5rem}
        .page-title{font-size:1.5rem;font-weight:700;color:var(--primary)}
        .stat-card{background:#fff;border-radius:12px;padding:1.25rem;box-shadow:0 2px 8px rgba(0,0,0,0.05);transition:transform .2s}
        .stat-card:hover{transform:translateY(-2px)}
        .stat-icon{width:48px;height:48px;border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:1.25rem}
        .stat-value{font-size:1.75rem;font-weight:700;color:var(--primary)}
        .stat-label{color:#6c757d;font-size:.85rem}
        .card-box{background:#fff;border-radius:12px;padding:1.25rem;box-shadow:0 2px 8px rgba(0,0,0,0.05)}
        .user-panel{position:absolute;bottom:0;width:100%;padding:1rem 1.2rem;border-top:1px solid rgba(255,255,255,0.1);display:flex;align-items:center;gap:.7rem}
        .avatar{width:36px;height:36px;border-radius:50%;background:var(--accent);display:flex;align-items:center;justify-content:center;color:#fff;font-weight:600;font-size:.85rem}
        .btn{padding:.5rem 1rem;border-radius:8px;border:none;cursor:pointer;font-size:.9rem;display:inline-flex;align-items:center;gap:.4rem}
        .btn-primary{background:var(--accent);color:#fff}
        .btn-success{background:#22c55e;color:#fff}
        .btn-outline{background:transparent;border:1px solid var(--accent);color:var(--accent)}
        .text-muted{color:#6c757d;font-size:.85rem}
        table{width:100%;border-collapse:collapse}
        th,td{padding:.75rem;text-align:right;border-bottom:1px solid #f0f0f0}
        th{font-weight:600;color:var(--primary);font-size:.85rem}
        td{font-size:.9rem}
        .badge{padding:.25rem .6rem;border-radius:6px;font-size:.75rem;font-weight:600}
        .badge-green{background:#dcfce7;color:#166534}
        .badge-yellow{background:#fef3c7;color:#92400e}
        .badge-red{background:#fde8e8;color:#991b1b}
        .tab-nav{display:flex;gap:.5rem;margin-bottom:1rem}
        .tab-btn{padding:.5rem 1rem;border-radius:8px;border:none;cursor:pointer;background:#e2e8f0;font-size:.9rem}
        .tab-btn.active{background:var(--accent);color:#fff}
        .form-group{margin-bottom:1rem}
        .form-group label{display:block;font-weight:600;margin-bottom:.4rem;font-size:.85rem;color:#374151}
        .form-control{width:100%;padding:.6rem .8rem;border:1px solid #d1d5db;border-radius:8px;font-size:.9rem;font-family:inherit}
        .form-control:focus{outline:none;border-color:var(--accent);box-shadow:0 0 0 3px rgba(49,130,206,0.15)}
        .grid-2{display:grid;grid-template-columns:1fr 1fr;gap:1rem}
        .grid-4{display:grid;grid-template-columns:repeat(4,1fr);gap:1rem;margin-bottom:1.5rem}
        .search-box{display:flex;gap:.5rem;margin-bottom:1rem}
        .search-box input{flex:1;padding:.6rem .8rem;border:1px solid #d1d5db;border-radius:8px;font-size:.9rem}
        .tab-content{display:none}
        .tab-content.active{display:block}
        .modal-overlay{display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);z-index:200;align-items:center;justify-content:center}
        .modal-overlay.active{display:flex}
        .modal{background:#fff;border-radius:12px;padding:1.5rem;width:90%;max-width:500px}
    </style>
</head>
<body>
    <aside class="sidebar">
        <div class="sidebar-brand"><i class="ti ti-book-2"></i> \u0645\u0643\u062a\u0628\u0629 \u0627\u0644\u062d\u0633\u064a\u0646\u064a</div>
        <nav style="padding:.75rem 0">
            <a class="nav-link" href="admin-dashboard.html"><i class="ti ti-layout-dashboard"></i> \u0644\u0648\u062d\u0629 \u0627\u0644\u062a\u062d\u0643\u0645</a>
            <a class="nav-link active" href="librarian-dashboard.html"><i class="ti ti-book"></i> \u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0643\u062a\u0628</a>
            <a class="nav-link" href="member-dashboard.html"><i class="ti ti-users"></i> \u0627\u0644\u0623\u0639\u0636\u0627\u0621</a>
            <a class="nav-link" href="#"><i class="ti ti-arrows-right-left"></i> \u0627\u0644\u0625\u0639\u0627\u0631\u0627\u062a</a>
            <a class="nav-link" href="#"><i class="ti ti-chart-bar"></i> \u0627\u0644\u062a\u0642\u0627\u0631\u064a\u0631</a>
        </nav>
        <div class="user-panel">
            <div class="avatar" id="userAvatar">\u0623</div>
            <div style="flex:1">
                <div id="userName" style="font-weight:600;font-size:.9rem">\u0623\u0645\u064a\u0646 \u0627\u0644\u0645\u0643\u062a\u0628\u0629</div>
                <div id="userRole" style="font-size:.7rem;opacity:.7">\u0623\u0645\u064a\u0646 \u0645\u0643\u062a\u0628\u0629</div>
            </div>
            <a href="#" onclick="logout()" style="color:#fff;font-size:1.1rem" title="\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c"><i class="ti ti-logout"></i></a>
        </div>
    </aside>

    <main class="main-content">
        <div class="page-header">
            <div>
                <div class="page-title">\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0645\u0643\u062a\u0628\u0629</div>
                <div class="text-muted">\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0643\u062a\u0628 \u0648\u0627\u0644\u0623\u0639\u0636\u0627\u0621 \u0648\u0627\u0644\u0625\u0639\u0627\u0631\u0627\u062a</div>
            </div>
        </div>

        <div class="grid-4">
            <div class="stat-card"><div style="display:flex;align-items:center;gap:1rem"><div class="stat-icon" style="background:#e8f4fd;color:#3182ce"><i class="ti ti-book-2"></i></div><div><div class="stat-value">12,458</div><div class="stat-label">\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0643\u062a\u0628</div></div></div></div>
            <div class="stat-card"><div style="display:flex;align-items:center;gap:1rem"><div class="stat-icon" style="background:#e8fdf4;color:#22c55e"><i class="ti ti-bookmark"></i></div><div><div class="stat-value">11,890</div><div class="stat-label">\u0645\u062a\u0627\u062d</div></div></div></div>
            <div class="stat-card"><div style="display:flex;align-items:center;gap:1rem"><div class="stat-icon" style="background:#fef3c7;color:#f59e0b"><i class="ti ti-arrows-right-left"></i></div><div><div class="stat-value">342</div><div class="stat-label">\u0645\u0639\u0627\u0631 \u062d\u0627\u0644\u064a\u0627\u064b</div></div></div></div>
            <div class="stat-card"><div style="display:flex;align-items:center;gap:1rem"><div class="stat-icon" style="background:#fde8e8;color:#ef4444"><i class="ti ti-clock"></i></div><div><div class="stat-value">28</div><div class="stat-label">\u0645\u062a\u0623\u062e\u0631\u0627\u062a</div></div></div></div>
        </div>

        <div class="tab-nav">
            <button class="tab-btn active" onclick="showTab('books')">\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0643\u062a\u0628</button>
            <button class="tab-btn" onclick="showTab('members')">\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0623\u0639\u0636\u0627\u0621</button>
            <button class="tab-btn" onclick="showTab('borrows')">\u0625\u0639\u0627\u0631\u0629 / \u0625\u0631\u062c\u0627\u0639</button>
        </div>

        <div id="tab-books" class="tab-content active">
            <div class="card-box">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem">
                    <h5 style="color:var(--primary);font-weight:600">\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u0643\u062a\u0628</h5>
                    <button class="btn btn-primary" onclick="document.getElementById('bookModal').classList.add('active')"><i class="ti ti-plus"></i> \u0625\u0636\u0627\u0641\u0629 \u0643\u062a\u0627\u0628</button>
                </div>
                <div class="search-box">
                    <input type="text" placeholder="\u0628\u062d\u062b \u0639\u0646 \u0643\u062a\u0627\u0628..." id="bookSearch" onkeyup="filterTable('booksTable','bookSearch')">
                    <button class="btn btn-primary"><i class="ti ti-search"></i></button>
                </div>
                <div style="overflow-x:auto">
                <table id="booksTable">
                    <thead><tr><th>\u0627\u0644\u0643\u0648\u062f</th><th>\u0627\u0644\u0639\u0646\u0648\u0627\u0646</th><th>\u0627\u0644\u0645\u0624\u0644\u0641</th><th>\u0627\u0644\u062a\u0635\u0646\u064a\u0641</th><th>\u0627\u0644\u062d\u0627\u0644\u0629</th><th>\u0625\u062c\u0631\u0627\u0621\u0627\u062a</th></tr></thead>
                    <tbody>
                        <tr><td>B001</td><td>\u0627\u0644\u0628\u062d\u062b \u0639\u0646 \u0648\u0637\u0646</td><td>\u062e\u0627\u0644\u062f \u062d\u0633\u064a\u0646\u064a</td><td>\u0631\u0648\u0627\u064a\u0629</td><td><span class="badge badge-green">\u0645\u062a\u0627\u062d</span></td><td><button class="btn btn-outline" style="padding:.3rem .6rem;font-size:.8rem"><i class="ti ti-edit"></i></button></td></tr>
                        <tr><td>B002</td><td>\u0623\u0644\u0641 \u0644\u064a\u0644\u0629 \u0648\u0644\u064a\u0644\u0629</td><td>\u062c\u0628\u0631\u0627\u0646 \u062e\u0644\u064a\u0644 \u062c\u0628\u0631\u0627\u0646</td><td>\u0623\u062f\u0628</td><td><span class="badge badge-yellow">\u0645\u0639\u0627\u0631</span></td><td><button class="btn btn-outline" style="padding:.3rem .6rem;font-size:.8rem"><i class="ti ti-edit"></i></button></td></tr>
                        <tr><td>B003</td><td>\u0627\u0644\u0644\u0635 \u0648\u0627\u0644\u0643\u0644\u0627\u0628</td><td>\u0646\u062c\u064a\u0628 \u0645\u062d\u0641\u0648\u0638</td><td>\u0631\u0648\u0627\u064a\u0629</td><td><span class="badge badge-green">\u0645\u062a\u0627\u062d</span></td><td><button class="btn btn-outline" style="padding:.3rem .6rem;font-size:.8rem"><i class="ti ti-edit"></i></button></td></tr>
                        <tr><td>B004</td><td>\u0627\u0644\u062b\u0644\u0627\u062b\u064a\u0629</td><td>\u063a\u0627\u0632\u064a \u0627\u0644\u0642\u0635\u064a\u0628\u064a</td><td>\u062a\u0627\u0631\u064a\u062e</td><td><span class="badge badge-red">\u063a\u064a\u0631 \u0645\u062a\u0627\u062d</span></td><td><button class="btn btn-outline" style="padding:.3rem .6rem;font-size:.8rem"><i class="ti ti-edit"></i></button></td></tr>
                        <tr><td>B005</td><td>\u0627\u0644\u062d\u064a \u0628\u0646 \u064a\u0642\u0638\u0627\u0646</td><td>\u0627\u0628\u0646 \u0637\u0641\u064a\u0644</td><td>\u0641\u0644\u0633\u0641\u0629</td><td><span class="badge badge-green">\u0645\u062a\u0627\u062d</span></td><td><button class="btn btn-outline" style="padding:.3rem .6rem;font-size:.8rem"><i class="ti ti-edit"></i></button></td></tr>
                        <tr><td>B006</td><td>\u0627\u0644\u0645\u0639\u0644\u0645\u0629</td><td>\u0645\u0647\u0627 \u0627\u0644\u0623\u0633\u062f</td><td>\u062a\u0639\u0644\u064a\u0645</td><td><span class="badge badge-green">\u0645\u062a\u0627\u062d</span></td><td><button class="btn btn-outline" style="padding:.3rem .6rem;font-size:.8rem"><i class="ti ti-edit"></i></button></td></tr>
                    </tbody>
                </table>
                </div>
            </div>
        </div>

        <div id="tab-members" class="tab-content">
            <div class="card-box">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem">
                    <h5 style="color:var(--primary);font-weight:600">\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u0623\u0639\u0636\u0627\u0621</h5>
                    <button class="btn btn-primary" onclick="document.getElementById('memberModal').classList.add('active')"><i class="ti ti-user-plus"></i> \u0625\u0636\u0627\u0641\u0629 \u0639\u0636\u0648</button>
                </div>
                <div class="search-box">
                    <input type="text" placeholder="\u0628\u062d\u062b \u0639\u0646 \u0639\u0636\u0648..." id="memberSearch" onkeyup="filterTable('membersTable','memberSearch')">
                    <button class="btn btn-primary"><i class="ti ti-search"></i></button>
                </div>
                <table id="membersTable">
                    <thead><tr><th>\u0627\u0644\u0631\u0642\u0645</th><th>\u0627\u0644\u0627\u0633\u0645</th><th>\u0627\u0644\u0628\u0631\u064a\u062f</th><th>\u0627\u0644\u0647\u0627\u062a\u0641</th><th>\u0627\u0644\u0639\u0636\u0648\u064a\u0629</th><th>\u0625\u062c\u0631\u0627\u0621\u0627\u062a</th></tr></thead>
                    <tbody>
                        <tr><td>M001</td><td>\u0623\u062d\u0645\u062f \u0645\u062d\u0645\u062f</td><td>ahmed@email.com</td><td>0501234567</td><td><span class="badge badge-green">\u0646\u0634\u0637</span></td><td><button class="btn btn-outline" style="padding:.3rem .6rem;font-size:.8rem"><i class="ti ti-edit"></i></button></td></tr>
                        <tr><td>M002</td><td>\u0641\u0627\u0637\u0645\u0629 \u0639\u0644\u064a</td><td>fatima@email.com</td><td>0507654321</td><td><span class="badge badge-green">\u0646\u0634\u0637</span></td><td><button class="btn btn-outline" style="padding:.3rem .6rem;font-size:.8rem"><i class="ti ti-edit"></i></button></td></tr>
                        <tr><td>M003</td><td>\u0639\u0645\u0631 \u062e\u0627\u0644\u062f</td><td>omar@email.com</td><td>0509876543</td><td><span class="badge badge-yellow">\u0645\u0646\u062a\u0647\u064a</span></td><td><button class="btn btn-outline" style="padding:.3rem .6rem;font-size:.8rem"><i class="ti ti-edit"></i></button></td></tr>
                        <tr><td>M004</td><td>\u0633\u0627\u0631\u0629 \u0623\u062d\u0645\u062f</td><td>sara@email.com</td><td>0505554444</td><td><span class="badge badge-green">\u0646\u0634\u0637</span></td><td><button class="btn btn-outline" style="padding:.3rem .6rem;font-size:.8rem"><i class="ti ti-edit"></i></button></td></tr>
                    </tbody>
                </table>
            </div>
        </div>

        <div id="tab-borrows" class="tab-content">
            <div class="grid-2">
                <div class="card-box">
                    <h5 style="color:var(--primary);font-weight:600;margin-bottom:1rem"><i class="ti ti-arrow-left"></i> \u0625\u0639\u0627\u0631\u0629 \u0643\u062a\u0627\u0628</h5>
                    <div class="form-group"><label>\u0627\u0644\u0639\u0636\u0648</label><select class="form-control"><option>\u0627\u062e\u062a\u0631 \u0627\u0644\u0639\u0636\u0648...</option><option>\u0623\u062d\u0645\u062f \u0645\u062d\u0645\u062f</option><option>\u0641\u0627\u0637\u0645\u0629 \u0639\u0644\u064a</option><option>\u0639\u0645\u0631 \u062e\u0627\u0644\u062f</option><option>\u0633\u0627\u0631\u0629 \u0623\u062d\u0645\u062f</option></select></div>
                    <div class="form-group"><label>\u0627\u0644\u0643\u062a\u0627\u0628</label><select class="form-control"><option>\u0627\u062e\u062a\u0631 \u0627\u0644\u0643\u062a\u0627\u0628...</option><option>\u0627\u0644\u0628\u062d\u062b \u0639\u0646 \u0648\u0637\u0646 - B001</option><option>\u0627\u0644\u0644\u0635 \u0648\u0627\u0644\u0643\u0644\u0627\u0628 - B003</option><option>\u0627\u0644\u062d\u064a \u0628\u0646 \u064a\u0642\u0638\u0627\u0646 - B005</option><option>\u0627\u0644\u0645\u0639\u0644\u0645\u0629 - B006</option></select></div>
                    <div class="form-group"><label>\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0633\u062a\u0639\u0627\u0631\u0629</label><input type="date" class="form-control"></div>
                    <div class="form-group"><label>\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0631\u062c\u0627\u0639 \u0627\u0644\u0645\u062a\u0648\u0642\u0639</label><input type="date" class="form-control"></div>
                    <button class="btn btn-primary" style="width:100%"><i class="ti ti-check"></i> \u062a\u0623\u0643\u064a\u062f \u0627\u0644\u0625\u0639\u0627\u0631\u0629</button>
                </div>
                <div class="card-box">
                    <h5 style="color:var(--primary);font-weight:600;margin-bottom:1rem"><i class="ti ti-arrow-right"></i> \u0625\u0631\u062c\u0627\u0639 \u0643\u062a\u0627\u0628</h5>
                    <div class="form-group"><label>\u0631\u0642\u0645 \u0627\u0644\u0625\u0639\u0627\u0631\u0629</label><input type="text" class="form-control" placeholder="\u0623\u062f\u062e\u0644 \u0631\u0642\u0645 \u0627\u0644\u0625\u0639\u0627\u0631\u0629"></div>
                    <div class="form-group"><label>\u0627\u0644\u0643\u062a\u0627\u0628</label><select class="form-control"><option>\u0627\u062e\u062a\u0631 \u0627\u0644\u0643\u062a\u0627\u0628 \u0627\u0644\u0645\u0639\u0627\u0631...</option><option>\u0623\u0644\u0641 \u0644\u064a\u0644\u0629 \u0648\u0644\u064a\u0644\u0629 - B002</option><option>\u0627\u0644\u062b\u0644\u0627\u062b\u064a\u0629 - B004</option></select></div>
                    <div class="form-group"><label>\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0631\u062c\u0627\u0639 \u0627\u0644\u0641\u0639\u0644\u064a</label><input type="date" class="form-control"></div>
                    <div class="form-group"><label>\u0645\u0644\u0627\u062d\u0638\u0627\u062a</label><textarea class="form-control" rows="3" placeholder="\u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0627\u062e\u062a\u064a\u0627\u0631\u064a\u0629..."></textarea></div>
                    <button class="btn btn-success" style="width:100%"><i class="ti ti-check"></i> \u062a\u0623\u0643\u064a\u062f \u0627\u0644\u0625\u0631\u062c\u0627\u0639</button>
                </div>
            </div>
            <div class="card-box" style="margin-top:1rem">
                <h5 style="color:var(--primary);font-weight:600;margin-bottom:1rem">\u0627\u0644\u0625\u0639\u0627\u0631\u0627\u062a \u0627\u0644\u0646\u0634\u0637\u0629</h5>
                <div style="overflow-x:auto">
                <table>
                    <thead><tr><th>\u0631\u0642\u0645 \u0627\u0644\u0625\u0639\u0627\u0631\u0629</th><th>\u0627\u0644\u0639\u0636\u0648</th><th>\u0627\u0644\u0643\u062a\u0627\u0628</th><th>\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0639\u0627\u0631\u0629</th><th>\u0627\u0644\u0625\u0631\u062c\u0627\u0639 \u0627\u0644\u0645\u062a\u0648\u0642\u0639</th><th>\u0627\u0644\u062d\u0627\u0644\u0629</th></tr></thead>
                    <tbody>
                        <tr><td>L001</td><td>\u0623\u062d\u0645\u062f \u0645\u062d\u0645\u062f</td><td>\u0623\u0644\u0641 \u0644\u064a\u0644\u0629 \u0648\u0644\u064a\u0644\u0629</td><td>2026/09/10</td><td>2026/09/24</td><td><span class="badge badge-green">\u0623\u0639\u0627\u062f\u064a</span></td></tr>
                        <tr><td>L002</td><td>\u0641\u0627\u0637\u0645\u0629 \u0639\u0644\u064a</td><td>\u0627\u0644\u062b\u0644\u0627\u062b\u064a\u0629</td><td>2026/09/01</td><td>2026/09/15</td><td><span class="badge badge-red">\u0645\u062a\u0623\u062e\u0631</span></td></tr>
                        <tr><td>L003</td><td>\u0633\u0627\u0631\u0629 \u0623\u062d\u0645\u062f</td><td>\u0623\u0644\u0641 \u0644\u064a\u0644\u0629 \u0648\u0644\u064a\u0644\u0629</td><td>2026/09/15</td><td>2026/09/29</td><td><span class="badge badge-green">\u0623\u0639\u0627\u062f\u064a</span></td></tr>
                    </tbody>
                </table>
                </div>
            </div>
        </div>
    </main>

    <div id="bookModal" class="modal-overlay" onclick="if(event.target===this)this.classList.remove('active')">
        <div class="modal">
            <h5 style="color:var(--primary);font-weight:600;margin-bottom:1rem">\u0625\u0636\u0627\u0641\u0629 \u0643\u062a\u0627\u0628 \u062c\u062f\u064a\u062f</h5>
            <div class="form-group"><label>\u0627\u0644\u0639\u0646\u0648\u0627\u0646</label><input type="text" class="form-control" placeholder="\u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u0643\u062a\u0627\u0628"></div>
            <div class="grid-2">
                <div class="form-group"><label>\u0627\u0644\u0645\u0624\u0644\u0641</label><input type="text" class="form-control" placeholder="\u0627\u0633\u0645 \u0627\u0644\u0645\u0624\u0644\u0641"></div>
                <div class="form-group"><label>\u0627\u0644\u062a\u0635\u0646\u064a\u0641</label><select class="form-control"><option>\u0631\u0648\u0627\u064a\u0629</option><option>\u0623\u062f\u0628</option><option>\u062a\u0627\u0631\u064a\u062e</option><option>\u0641\u0644\u0633\u0641\u0629</option><option>\u062a\u0639\u0644\u064a\u0645</option></select></div>
            </div>
            <div class="grid-2">
                <div class="form-group"><label>\u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u062f\u0648\u0644\u064a</label><input type="text" class="form-control" placeholder="ISBN"></div>
                <div class="form-group"><label>\u0627\u0644\u0646\u0633\u062e</label><input type="number" class="form-control" value="1"></div>
            </div>
            <div style="display:flex;gap:.5rem;justify-content:flex-end;margin-top:1rem">
                <button class="btn btn-outline" onclick="document.getElementById('bookModal').classList.remove('active')">\u0625\u0644\u063a\u0627\u0621</button>
                <button class="btn btn-primary" onclick="document.getElementById('bookModal').classList.remove('active')">\u062d\u0641\u0638</button>
            </div>
        </div>
    </div>

    <div id="memberModal" class="modal-overlay" onclick="if(event.target===this)this.classList.remove('active')">
        <div class="modal">
            <h5 style="color:var(--primary);font-weight:600;margin-bottom:1rem">\u0625\u0636\u0627\u0641\u0629 \u0639\u0636\u0648 \u062c\u062f\u064a\u062f</h5>
            <div class="form-group"><label>\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0643\u0627\u0645\u0644</label><input type="text" class="form-control" placeholder="\u0627\u0633\u0645 \u0627\u0644\u0639\u0636\u0648"></div>
            <div class="grid-2">
                <div class="form-group"><label>\u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a</label><input type="email" class="form-control" placeholder="email@example.com"></div>
                <div class="form-group"><label>\u0627\u0644\u0647\u0627\u062a\u0641</label><input type="tel" class="form-control" placeholder="05XXXXXXXX"></div>
            </div>
            <div style="display:flex;gap:.5rem;justify-content:flex-end;margin-top:1rem">
                <button class="btn btn-outline" onclick="document.getElementById('memberModal').classList.remove('active')">\u0625\u0644\u063a\u0627\u0621</button>
                <button class="btn btn-primary" onclick="document.getElementById('memberModal').classList.remove('active')">\u062d\u0641\u0638</button>
            </div>
        </div>
    </div>

    <script>
        function checkAuth() {
            var token = localStorage.getItem('library_token');
            if (!token) { window.location.href = 'login.html'; return; }
            var user = JSON.parse(localStorage.getItem('library_user') || '{}');
            if (user.name) document.getElementById('userName').textContent = user.name;
            if (user.role) document.getElementById('userRole').textContent = user.role;
            if (user.name) document.getElementById('userAvatar').textContent = user.name.charAt(0);
        }
        function logout() {
            localStorage.removeItem('library_token');
            localStorage.removeItem('library_user');
            window.location.href = 'login.html';
        }
        function showTab(name) {
            document.querySelectorAll('.tab-content').forEach(function(el) { el.classList.remove('active'); });
            document.querySelectorAll('.tab-btn').forEach(function(el) { el.classList.remove('active'); });
            document.getElementById('tab-' + name).classList.add('active');
            event.target.classList.add('active');
        }
        function filterTable(tableId, inputId) {
            var filter = document.getElementById(inputId).value.toLowerCase();
            var rows = document.getElementById(tableId).querySelectorAll('tbody tr');
            rows.forEach(function(row) {
                row.style.display = row.textContent.toLowerCase().includes(filter) ? '' : 'none';
            });
        }
        checkAuth();
    </script>
</body>
</html>`;

fs.writeFileSync(path, content, 'utf8');
console.log('librarian-dashboard.html written');
