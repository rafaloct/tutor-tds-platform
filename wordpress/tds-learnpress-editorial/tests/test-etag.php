<?php
/** Focal regression; the included suite provides synthetic WP/LP fixtures. */
require __DIR__ . '/test-contract.php';
$baseline_checks = $checks;
$posts[1425]->post_content = '<p>Public synthetic lesson.</p>';
update_post_meta( 1425, '_tds_mobile_public', '1' );
foreach ( array( 'course', 'lesson' ) as $kind ) {
	$read = 'course' === $kind
		? fn( $tag = '' ) => request_course( 1356, $tag )
		: fn( $tag = '' ) => request_lesson( 1425, $tag );
	$initial = $read();
	$tag = $initial->headers['ETag'];
	foreach ( array( $tag, 'W/' . $tag, " \tW/" . $tag . "\t " ) as $valid ) {
		$response = $read( $valid );
		verify( 304 === $response->get_status(), $kind . ': current validator revalidates' );
		verify( null === $response->get_data(), $kind . ': 304 has no payload' );
		verify( $tag === $response->headers['ETag'], $kind . ': canonical ETag retained' );
	}
	foreach ( array(
		'', '"different"', 'W/"different"', 'w/' . $tag, 'W/W/' . $tag,
		'W/' . trim( $tag, '"' ), $tag . 'suffix', "W/ $tag",
		$tag . "\r\n", 'prefix' . $tag, '*', '"other", ' . $tag,
	) as $invalid ) {
		verify( 200 === $read( $invalid )->get_status(), $kind . ': nonmatching or unsupported validator sends full response' );
	}
	$posts[1425]->post_title .= ' changed';
	verify( 200 === $read( 'W/' . $tag )->get_status(), $kind . ': stale weak validator invalidated' );
}
$lesson_tag = request_lesson()->headers['ETag'];
update_post_meta( 1425, '_tds_mobile_public', '0' );
verify( request_lesson( 1425, 'W/' . $lesson_tag )->code === 'tds_editorial_lesson_not_authorized', 'Revoked opt-in checked before cache' );
update_post_meta( 1425, '_tds_mobile_public', '1' );
$posts[1425]->post_status = 'draft';
verify( request_lesson( 1425, 'W/' . $lesson_tag )->code === 'tds_editorial_lesson_not_authorized', 'Draft denied before cache' );
$posts[1356]->post_status = 'private';
verify( request_course( 1356, 'W/' . $tag )->code === 'tds_editorial_course_not_published', 'Private course denied before cache' );
echo 'PHP_ETAG_FOCAL_PASS=' . ( $checks - $baseline_checks ) . "\n";
