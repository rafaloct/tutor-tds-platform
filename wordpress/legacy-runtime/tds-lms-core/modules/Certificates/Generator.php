<?php
namespace TDS\Certificates;

class Generator {
    public function __construct() {
        add_action('learnpress_user_finish_course', [$this, 'generate'], 20, 2);
    }

    public static function build_hash(int $user_id, string $course_slug, string $date): string {
        return hash('sha256', $user_id . $course_slug . $date . TDS_API_KEY);
    }

    public static function mask_cpf(string $cpf): string {
        if (!$cpf) return '';
        return preg_replace('/(\d{3})\.\d{3}\.\d{3}-(\d{2})/', '$1.***.***-$2', $cpf) ?? $cpf;
    }

    public function generate(int $user_id, int $course_id): void {
        $user        = get_user_by('id', $user_id);
        $course_slug = get_post_field('post_name', $course_id);
        $course_name = get_the_title($course_id);
        $date        = gmdate('Y-m-d');
        $hash        = self::build_hash($user_id, $course_slug, $date);
        $cpf         = self::mask_cpf(get_user_meta($user_id, 'billing_cpf', true) ?: '');
        $dir         = WP_CONTENT_DIR . '/uploads/tds-certificates/';

        if (!is_dir($dir)) wp_mkdir_p($dir);

        $pdf_path = $dir . "{$user_id}-{$course_slug}.pdf";
        $this->build_pdf($pdf_path, [
            'student_name' => $user ? $user->display_name : 'Aluno',
            'course_name'  => $course_name,
            'date'         => gmdate('d/m/Y'),
            'hash'         => $hash,
            'cpf'          => $cpf,
            'verify_url'   => home_url('/verificar/' . $hash),
        ]);

        $this->save_to_db($user_id, $course_slug, $hash, $date);
    }

    private function build_pdf(string $path, array $data): void {
        $pdf = new \TCPDF('L', 'mm', 'A4', true, 'UTF-8');
        $pdf->SetCreator('TDS Capacitação');
        $pdf->SetAuthor('TDS');
        $pdf->SetTitle('Certificado — ' . $data['course_name']);
        $pdf->setPrintHeader(false);
        $pdf->setPrintFooter(false);
        $pdf->SetMargins(20, 20, 20);
        $pdf->AddPage();

        $pdf->SetFillColor(29, 27, 116);
        $pdf->Rect(0, 0, 297, 210, 'F');

        $pdf->SetTextColor(246, 215, 70);
        $pdf->SetFont('helvetica', 'B', 28);
        $pdf->SetY(30);
        $pdf->Cell(0, 15, 'CERTIFICADO DE CONCLUSÃO', 0, 1, 'C');

        $pdf->SetFont('helvetica', '', 14);
        $pdf->SetTextColor(255, 255, 255);
        $pdf->Cell(0, 10, 'Este certificado é concedido a', 0, 1, 'C');

        $pdf->SetFont('helvetica', 'B', 22);
        $pdf->SetTextColor(246, 215, 70);
        $pdf->Cell(0, 14, $data['student_name'], 0, 1, 'C');
        if ($data['cpf']) {
            $pdf->SetFont('helvetica', '', 11);
            $pdf->SetTextColor(200, 200, 200);
            $pdf->Cell(0, 8, 'CPF: ' . $data['cpf'], 0, 1, 'C');
        }

        $pdf->SetFont('helvetica', '', 14);
        $pdf->SetTextColor(255, 255, 255);
        $pdf->Ln(5);
        $pdf->Cell(0, 10, 'pelo aproveitamento do curso', 0, 1, 'C');
        $pdf->SetFont('helvetica', 'B', 18);
        $pdf->SetTextColor(24, 207, 16);
        $pdf->Cell(0, 12, $data['course_name'], 0, 1, 'C');

        $pdf->SetFont('helvetica', '', 12);
        $pdf->SetTextColor(200, 200, 200);
        $pdf->Ln(5);
        $pdf->Cell(0, 8, 'Emitido em: ' . $data['date'], 0, 1, 'C');

        $style = ['border' => false, 'padding' => 0, 'fgcolor' => [255, 255, 255], 'bgcolor' => [29, 27, 116]];
        $pdf->write2DBarcode($data['verify_url'], 'QRCODE,H', 125, 165, 30, 30, $style, 'N');

        $pdf->SetFont('courier', '', 8);
        $pdf->SetTextColor(100, 100, 100);
        $pdf->SetXY(0, 200);
        $pdf->Cell(0, 5, 'Hash: ' . $data['hash'], 0, 0, 'C');

        $pdf->Output($path, 'F');
    }

    private function save_to_db(int $user_id, string $course_slug, string $hash, string $date): void {
        global $wpdb;
        $wpdb->replace(
            "{$wpdb->prefix}tds_certificates",
            ['user_id' => $user_id, 'course_slug' => $course_slug, 'hash' => $hash, 'issued_at' => $date],
            ['%d', '%s', '%s', '%s']
        );
    }

    public static function create_table(): void {
        global $wpdb;
        $charset = $wpdb->get_charset_collate();
        $sql = "CREATE TABLE IF NOT EXISTS {$wpdb->prefix}tds_certificates (
            id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            user_id     BIGINT UNSIGNED NOT NULL,
            course_slug VARCHAR(200) NOT NULL,
            hash        VARCHAR(64) NOT NULL UNIQUE,
            issued_at   DATE NOT NULL,
            INDEX idx_user (user_id),
            INDEX idx_slug (course_slug)
        ) $charset;";
        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        dbDelta($sql);
    }
}
