<?php
namespace TDS\Reports;

class AdminPanel {
    public function __construct() {
        add_action('admin_menu', [$this, 'add_menu']);
    }

    public function add_menu(): void {
        add_submenu_page(
            'learnpress', 'TDS — Relatórios', 'Relatórios TDS',
            'manage_options', 'tds-reports', [$this, 'render_page']
        );
    }

    public function render_page(): void {
        global $wpdb;
        $total_students  = (int) $wpdb->get_var("SELECT COUNT(DISTINCT user_id) FROM {$wpdb->prefix}learnpress_user_items WHERE item_type='lp_course'");
        $total_enrolled  = (int) $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}learnpress_user_items WHERE item_type='lp_course' AND status='enrolled'");
        $total_completed = (int) $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}learnpress_user_items WHERE item_type='lp_course' AND status='finished'");
        $total_certs     = (int) $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}tds_certificates");

        $by_course = $wpdb->get_results("
            SELECT p.post_title, COUNT(*) as total,
                   SUM(CASE WHEN ui.status='finished' THEN 1 ELSE 0 END) as completed
            FROM {$wpdb->prefix}learnpress_user_items ui
            JOIN {$wpdb->posts} p ON p.ID = ui.item_id
            WHERE ui.item_type = 'lp_course'
            GROUP BY ui.item_id ORDER BY total DESC LIMIT 20
        ");
        ?>
        <div class="wrap">
          <h1>TDS — Relatórios LMS</h1>
          <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:1rem;margin:1.5rem 0">
            <?php foreach([
              ['Alunos únicos', $total_students], ['Matrículas ativas', $total_enrolled],
              ['Cursos concluídos', $total_completed], ['Certificados emitidos', $total_certs]
            ] as [$label, $val]): ?>
            <div style="background:#fff;border:1px solid #ddd;border-radius:6px;padding:1rem;text-align:center">
              <div style="font-size:2rem;font-weight:700;color:#073AF5"><?= (int)$val ?></div>
              <div style="font-size:.85rem;color:#666"><?= esc_html($label) ?></div>
            </div>
            <?php endforeach; ?>
          </div>
          <h2>Por Curso</h2>
          <table class="wp-list-table widefat striped">
            <thead><tr><th>Curso</th><th>Matrículas</th><th>Concluídos</th><th>Taxa</th></tr></thead>
            <tbody>
            <?php foreach ($by_course as $row): ?>
              <tr>
                <td><?= esc_html($row->post_title) ?></td>
                <td><?= (int)$row->total ?></td>
                <td><?= (int)$row->completed ?></td>
                <td><?= $row->total ? round(($row->completed / $row->total) * 100) . '%' : '—' ?></td>
              </tr>
            <?php endforeach; ?>
            </tbody>
          </table>
        </div>
        <?php
    }
}
