<?php
// Administrative editorial operation, NOT an HTTP save test or teacher RBAC proof.
$id = 1420;
$content_hash = 'cb5e79c4bd6a9c4bae86664d3675e8cd3e1fa7ada769f602a2bf73122084f14d';
$fingerprint = '0b2b5bfa36ba53b5b0c99cc8f8951ca99e70d76af7f131fc775998fed8e7f5c8';
$keys = array('_tds_mobile_public','_tds_mobile_rights_approved','_tds_mobile_youtube_id',
    '_tds_mobile_poster_url','_tds_mobile_captions_url',
    '_tds_mobile_rights_pending_source_fingerprint','_tds_mobile_rights_source_fingerprint');
function ensure_pilot($ok) {
    if (!$ok) { throw new RuntimeException('Pilot precondition failed; stop'); }
}
ensure_pilot(home_url() === 'https://ead.ipexdesenvolvimento.cloud');
ensure_pilot(in_array('administrator', wp_get_current_user()->roles, true));
ensure_pilot(current_user_can('edit_post',$id) && current_user_can('edit_post',1298));
$post = get_post($id);
ensure_pilot($post && $post->post_status === 'publish' && $post->post_type === 'lp_lesson');
ensure_pilot(hash('sha256',$post->post_content) === $content_hash);
ensure_pilot(TDS_LearnPress_Editorial::mp4_source_fingerprint($id) === $fingerprint);
global $wpdb;
$parents = $wpdb->get_col($wpdb->prepare(
    "SELECT DISTINCT s.section_course_id FROM {$wpdb->prefix}learnpress_section_items si
     JOIN {$wpdb->prefix}learnpress_sections s ON s.section_id=si.section_id WHERE si.item_id=%d", $id));
ensure_pilot(array_map('intval',$parents) === array(1298));
$before = array();
foreach ($keys as $key) { $before[$key] = get_post_meta($id,$key,false); }
if ($args[0] === 'snapshot') {
    echo wp_json_encode(array('id'=>$id,'meta'=>$before,'content_sha256'=>$content_hash,
        'fingerprint'=>$fingerprint,'author'=>(int)$post->post_author));
    return;
}
$baseline = json_decode(base64_decode($args[1],true),true);
ensure_pilot(is_array($baseline) && $baseline['id'] === $id);
if ($args[0] === 'publish') {
    ensure_pilot($baseline['meta'] === $before);
    foreach ($before as $values) { ensure_pilot(count($values) === 0); }
    // Two distinct explicit saves through the deployed metabox validator.
    // No post/content/curriculum write; no capability mapping or elevated role.
    $states = array();
    foreach (array('0','1') as $approve) {
        $_POST = array('tds_mobile_lesson_nonce'=>wp_create_nonce('tds_mobile_lesson_'.$id),
            'tds_mobile_youtube_id'=>'','tds_mobile_poster_url'=>'','tds_mobile_captions_url'=>'');
        if ($approve === '1') {
            $_POST['tds_mobile_public'] = '1';
            $_POST['tds_mobile_rights_approved'] = '1';
        }
        TDS_LearnPress_Editorial_Admin::save($id,get_post($id));
        ensure_pilot(get_post_meta($id,'_tds_mobile_rights_approved',true) === $approve);
        $states[] = $approve;
    }
    ensure_pilot(get_post_meta($id,'_tds_mobile_rights_source_fingerprint',true) === $fingerprint);
    ensure_pilot(hash('sha256',get_post($id)->post_content) === $content_hash);
    echo wp_json_encode(array('status'=>'PASS','id'=>$id,'rights_states'=>$states,
        'fingerprint'=>$fingerprint,'public'=>get_post_meta($id,'_tds_mobile_public',true),
        'method'=>'administrator CLI invoking deployed editorial metabox validator; not HTTP'));
} elseif ($args[0] === 'rollback') {
    foreach ($keys as $key) {
        // This pilot started with no metadata; refuse foreign edits.
        ensure_pilot(count($baseline['meta'][$key]) === 0);
        $expected = in_array($key,array('_tds_mobile_public','_tds_mobile_rights_approved'),true)
            ? '1' : (strpos($key,'fingerprint') !== false ? $fingerprint : '');
        ensure_pilot($before[$key] === array($expected));
    }
    foreach ($keys as $key) { delete_post_meta($id,$key); }
    echo wp_json_encode(array('rollback'=>'PASS','id'=>$id));
} else {
    throw new RuntimeException('Unsupported mode');
}
