<?php
// Read-only inventory; intentionally excludes users, enrollments and private text.
if ( home_url() !== 'https://ead.ipexdesenvolvimento.cloud' ) {
    throw new RuntimeException('Unexpected site');
}
$ids = array(614,1298,1307,1314,1321,1328,1335,1343,1356);
global $wpdb;
$result = array('courses'=>array(), 'lessons'=>array());
foreach ($ids as $id) {
    $p = get_post($id);
    if (!$p || $p->post_type !== 'lp_course' || $p->post_status !== 'publish') {
        throw new RuntimeException('Course not public');
    }
    $result['courses'][] = array('id'=>$id,'title'=>$p->post_title,'author'=>(int)$p->post_author);
    $lessons = $wpdb->get_col($wpdb->prepare(
        "SELECT DISTINCT si.item_id FROM {$wpdb->prefix}learnpress_section_items si
         JOIN {$wpdb->prefix}learnpress_sections s ON s.section_id=si.section_id
         WHERE s.section_course_id=%d AND si.item_type='lp_lesson'", $id));
    foreach ($lessons as $lid) {
        $lp = get_post($lid);
        $parents = $wpdb->get_col($wpdb->prepare(
            "SELECT DISTINCT s.section_course_id FROM {$wpdb->prefix}learnpress_section_items si
             JOIN {$wpdb->prefix}learnpress_sections s ON s.section_id=si.section_id
             WHERE si.item_id=%d", $lid));
        $entry = array('course_id'=>$id,'lesson_id'=>(int)$lid,'status'=>$lp->post_status,
            'author'=>(int)$lp->post_author,'parents'=>array_map('intval',$parents),
            'title'=>$lp->post_title,'content_sha256'=>hash('sha256',$lp->post_content),
            'fingerprint'=>TDS_LearnPress_Editorial::mp4_source_fingerprint($lid),
            'mobile_public'=>get_post_meta($lid,'_tds_mobile_public',true),
            'rights'=>get_post_meta($lid,'_tds_mobile_rights_approved',true));
        if ($lp->post_status === 'publish') {
            preg_match_all('#https://ead\.ipexdesenvolvimento\.cloud/wp-content/uploads/tutor-tds/[^"\'<>\s]+\.(?:mp4|vtt)#i',
                html_entity_decode($lp->post_content,ENT_QUOTES,'UTF-8'), $matches);
            $entry['media'] = array_values(array_unique($matches[0]));
        }
        if ((int)$lid === 1420 && $lp->post_status === 'publish') {
            $entry['pilot_public_content'] = $lp->post_content;
        }
        $result['lessons'][] = $entry;
    }
}
echo wp_json_encode($result,JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE);
