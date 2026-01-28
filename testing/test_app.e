note
	description: "Test application for SIMPLE_NET"
	author: "simple_net team"
	date: "2026-01-28"

class TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run the tests.
		do
			print ("Running SIMPLE_NET tests...%N%N")
			passed := 0
			failed := 0

			-- Initialize test suites
			create lib_tests
			create address_tests
			create error_type_tests
			create client_socket_tests
			create server_socket_tests
			create scoop_consumer_tests
			create scoop_concurrency_tests
			create precondition_investigation_tests
			create precondition_analysis_tests
			create simple_violation_tests

			run_lib_tests
			run_address_tests
			run_error_type_tests
			run_client_socket_tests
			run_server_socket_tests
			run_scoop_consumer_tests
			run_scoop_concurrency_tests
			run_precondition_investigation_tests
			run_precondition_analysis_tests
			run_simple_violation_tests

			print ("%N========================%N")
			print ("Results: " + passed.out + " passed, " + failed.out + " failed%N")

			if failed > 0 then
				print ("TESTS FAILED%N")
			else
				print ("ALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Test Runners

	run_lib_tests
			-- Run LIB_TESTS
		do
			print ("%N=== LIB_TESTS ===%N")
			-- Core functionality tests
			run_test (agent lib_tests.test_address_creation, "test_address_creation")
			run_test (agent lib_tests.test_address_loopback, "test_address_loopback")
			run_test (agent lib_tests.test_address_as_string, "test_address_as_string")
			run_test (agent lib_tests.test_error_type_creation, "test_error_type_creation")
			run_test (agent lib_tests.test_error_type_windows_codes, "test_error_type_windows_codes")
			run_test (agent lib_tests.test_error_type_classification, "test_error_type_classification")
			run_test (agent lib_tests.test_client_socket_creation, "test_client_socket_creation")
			run_test (agent lib_tests.test_client_socket_timeout, "test_client_socket_timeout")
			run_test (agent lib_tests.test_client_socket_state_machine, "test_client_socket_state_machine")
			run_test (agent lib_tests.test_server_socket_creation, "test_server_socket_creation")
			run_test (agent lib_tests.test_server_socket_timeout, "test_server_socket_timeout")
			run_test (agent lib_tests.test_server_socket_state_machine, "test_server_socket_state_machine")
		end

	run_address_tests
			-- Run TEST_ADDRESS
		do
			print ("%N=== TEST_ADDRESS ===%N")
			run_test (agent address_tests.test_make_for_host_port_creates_address, "test_make_for_host_port_creates_address")
			run_test (agent address_tests.test_make_for_localhost_port_creates_loopback_address, "test_make_for_localhost_port_creates_loopback_address")
			run_test (agent address_tests.test_make_for_host_port_rejects_empty_host, "test_make_for_host_port_rejects_empty_host")
			run_test (agent address_tests.test_make_for_host_port_rejects_invalid_port_zero, "test_make_for_host_port_rejects_invalid_port_zero")
			run_test (agent address_tests.test_make_for_host_port_rejects_invalid_port_negative, "test_make_for_host_port_rejects_invalid_port_negative")
			run_test (agent address_tests.test_make_for_host_port_rejects_invalid_port_over_65535, "test_make_for_host_port_rejects_invalid_port_over_65535")
			run_test (agent address_tests.test_as_string_formats_address_correctly, "test_as_string_formats_address_correctly")
			run_test (agent address_tests.test_is_ipv4_address_detects_ipv4, "test_is_ipv4_address_detects_ipv4")
			run_test (agent address_tests.test_is_loopback_identifies_loopback, "test_is_loopback_identifies_loopback")
			run_test (agent address_tests.test_address_immutable_after_creation, "test_address_immutable_after_creation")
		end

	run_error_type_tests
			-- Run TEST_ERROR_TYPE
		do
			print ("%N=== TEST_ERROR_TYPE ===%N")
			run_test (agent error_type_tests.test_make_creates_error_type, "test_make_creates_error_type")
			run_test (agent error_type_tests.test_to_string_no_error, "test_to_string_no_error")
			run_test (agent error_type_tests.test_is_fatal_bind_error, "test_is_fatal_bind_error")
			run_test (agent error_type_tests.test_is_retriable_connection_refused, "test_is_retriable_connection_refused")
			run_test (agent error_type_tests.test_is_connection_refused_linux, "test_is_connection_refused_linux")
			run_test (agent error_type_tests.test_is_connection_refused_windows, "test_is_connection_refused_windows")
			run_test (agent error_type_tests.test_is_connection_timeout, "test_is_connection_timeout")
			run_test (agent error_type_tests.test_is_connection_reset, "test_is_connection_reset")
			run_test (agent error_type_tests.test_is_bind_error, "test_is_bind_error")
			run_test (agent error_type_tests.test_is_address_not_available, "test_is_address_not_available")
			run_test (agent error_type_tests.test_is_read_error, "test_is_read_error")
			run_test (agent error_type_tests.test_is_write_error, "test_is_write_error")
			run_test (agent error_type_tests.test_is_no_error, "test_is_no_error")
			run_test (agent error_type_tests.test_is_retriable_timeout, "test_is_retriable_timeout")
			run_test (agent error_type_tests.test_is_fatal_address_error, "test_is_fatal_address_error")
			run_test (agent error_type_tests.test_to_string_connection_refused, "test_to_string_connection_refused")
			run_test (agent error_type_tests.test_to_string_unknown_error, "test_to_string_unknown_error")
		end

	run_client_socket_tests
			-- Run TEST_CLIENT_SOCKET
		do
			print ("%N=== TEST_CLIENT_SOCKET ===%N")
			run_test (agent client_socket_tests.test_make_for_host_port, "test_make_for_host_port")
			run_test (agent client_socket_tests.test_make_for_address, "test_make_for_address")
			run_test (agent client_socket_tests.test_set_timeout, "test_set_timeout")
			run_test (agent client_socket_tests.test_set_timeout_updates_timeout, "test_set_timeout_updates_timeout")
			run_test (agent client_socket_tests.test_set_timeout_boundary_values, "test_set_timeout_boundary_values")
			run_test (agent client_socket_tests.test_not_connected_initially, "test_not_connected_initially")
			run_test (agent client_socket_tests.test_connect_success_implies_connected, "test_connect_success_implies_connected")
			run_test (agent client_socket_tests.test_connect_failure_implies_error, "test_connect_failure_implies_error")
			run_test (agent client_socket_tests.test_connected_excludes_error, "test_connected_excludes_error")
			run_test (agent client_socket_tests.test_connected_excludes_closed, "test_connected_excludes_closed")
			run_test (agent client_socket_tests.test_error_excludes_closed, "test_error_excludes_closed")
			run_test (agent client_socket_tests.test_state_transition_connect_then_close, "test_state_transition_connect_then_close")
			run_test (agent client_socket_tests.test_state_transition_close_then_connect, "test_state_transition_close_then_connect")
			run_test (agent client_socket_tests.test_bytes_sent_zero_initially, "test_bytes_sent_zero_initially")
			run_test (agent client_socket_tests.test_bytes_sent_monotonic_increasing, "test_bytes_sent_monotonic_increasing")
			run_test (agent client_socket_tests.test_bytes_non_negative, "test_bytes_non_negative")
			run_test (agent client_socket_tests.test_send_increments_bytes_sent, "test_send_increments_bytes_sent")
			run_test (agent client_socket_tests.test_send_string_increments_bytes_sent, "test_send_string_increments_bytes_sent")
			run_test (agent client_socket_tests.test_receive_string_returns_string, "test_receive_string_returns_string")
			run_test (agent client_socket_tests.test_receive_on_eof_returns_empty, "test_receive_on_eof_returns_empty")
			run_test (agent client_socket_tests.test_close_sets_closed_flag, "test_close_sets_closed_flag")
			run_test (agent client_socket_tests.test_close_idempotent, "test_close_idempotent")
			run_test (agent client_socket_tests.test_remote_address_not_void, "test_remote_address_not_void")
			run_test (agent client_socket_tests.test_timeout_positive, "test_timeout_positive")
			run_test (agent client_socket_tests.test_timeout_persists_across_operations, "test_timeout_persists_across_operations")
			run_test (agent client_socket_tests.test_not_at_eof_initially, "test_not_at_eof_initially")
			run_test (agent client_socket_tests.test_ipv4_validation_accuracy, "test_ipv4_validation_accuracy")
			run_test (agent client_socket_tests.test_multiple_consecutive_sends, "test_multiple_consecutive_sends")
			run_test (agent client_socket_tests.test_extreme_port_values, "test_extreme_port_values")
			run_test (agent client_socket_tests.test_socket_with_empty_hostname, "test_socket_with_empty_hostname")
			run_test (agent client_socket_tests.test_send_on_disconnected_socket, "test_send_on_disconnected_socket")
			run_test (agent client_socket_tests.test_receive_on_disconnected_socket, "test_receive_on_disconnected_socket")
			run_test (agent client_socket_tests.test_connect_on_already_connected_socket, "test_connect_on_already_connected_socket")
			run_test (agent client_socket_tests.test_large_byte_count_tracking, "test_large_byte_count_tracking")
		end

	run_server_socket_tests
			-- Run TEST_SERVER_SOCKET
		do
			print ("%N=== TEST_SERVER_SOCKET ===%N")
			run_test (agent server_socket_tests.test_make_for_port, "test_make_for_port")
			run_test (agent server_socket_tests.test_make_for_address, "test_make_for_address")
			run_test (agent server_socket_tests.test_set_timeout, "test_set_timeout")
			run_test (agent server_socket_tests.test_set_timeout_updates_timeout, "test_set_timeout_updates_timeout")
			run_test (agent server_socket_tests.test_set_timeout_boundary_values, "test_set_timeout_boundary_values")
			run_test (agent server_socket_tests.test_not_listening_initially, "test_not_listening_initially")
			run_test (agent server_socket_tests.test_listen_success_implies_listening, "test_listen_success_implies_listening")
			run_test (agent server_socket_tests.test_listen_failure_implies_error, "test_listen_failure_implies_error")
			run_test (agent server_socket_tests.test_listening_excludes_error, "test_listening_excludes_error")
			run_test (agent server_socket_tests.test_listening_excludes_closed, "test_listening_excludes_closed")
			run_test (agent server_socket_tests.test_error_excludes_closed, "test_error_excludes_closed")
			run_test (agent server_socket_tests.test_state_transition_listen_then_close, "test_state_transition_listen_then_close")
			run_test (agent server_socket_tests.test_state_transition_close_then_listen, "test_state_transition_close_then_listen")
			run_test (agent server_socket_tests.test_connection_count_zero_initially, "test_connection_count_zero_initially")
			run_test (agent server_socket_tests.test_connection_count_non_negative, "test_connection_count_non_negative")
			run_test (agent server_socket_tests.test_connection_count_non_decreasing, "test_connection_count_non_decreasing")
			run_test (agent server_socket_tests.test_accept_void_on_timeout, "test_accept_void_on_timeout")
			run_test (agent server_socket_tests.test_accept_on_non_listening_socket, "test_accept_on_non_listening_socket")
			run_test (agent server_socket_tests.test_listen_with_various_backlog_values, "test_listen_with_various_backlog_values")
			run_test (agent server_socket_tests.test_backlog_persistence, "test_backlog_persistence")
			run_test (agent server_socket_tests.test_backlog_zero_initially, "test_backlog_zero_initially")
			run_test (agent server_socket_tests.test_backlog_non_negative, "test_backlog_non_negative")
			run_test (agent server_socket_tests.test_listen_stores_backlog, "test_listen_stores_backlog")
			run_test (agent server_socket_tests.test_close_sets_closed_flag, "test_close_sets_closed_flag")
			run_test (agent server_socket_tests.test_close_idempotent, "test_close_idempotent")
			run_test (agent server_socket_tests.test_local_address_not_void, "test_local_address_not_void")
			run_test (agent server_socket_tests.test_timeout_positive, "test_timeout_positive")
			run_test (agent server_socket_tests.test_timeout_persists_across_operations, "test_timeout_persists_across_operations")
			run_test (agent server_socket_tests.test_listen_on_already_listening_socket, "test_listen_on_already_listening_socket")
			run_test (agent server_socket_tests.test_state_consistency_after_failed_listen, "test_state_consistency_after_failed_listen")
			run_test (agent server_socket_tests.test_extreme_port_values, "test_extreme_port_values")
			run_test (agent server_socket_tests.test_negative_port_invalid, "test_negative_port_invalid")
			run_test (agent server_socket_tests.test_zero_port_invalid, "test_zero_port_invalid")
			run_test (agent server_socket_tests.test_port_over_65535_invalid, "test_port_over_65535_invalid")
		end

	run_scoop_consumer_tests
			-- Run TEST_SCOOP_CONSUMER
		do
			print ("%N=== TEST_SCOOP_CONSUMER ===%N")
			run_test (agent scoop_consumer_tests.test_client_socket_type_in_scoop_context, "test_client_socket_type_in_scoop_context")
			run_test (agent scoop_consumer_tests.test_server_socket_type_in_scoop_context, "test_server_socket_type_in_scoop_context")
			run_test (agent scoop_consumer_tests.test_connection_type_in_scoop_context, "test_connection_type_in_scoop_context")
			run_test (agent scoop_consumer_tests.test_address_type_in_scoop_context, "test_address_type_in_scoop_context")
			run_test (agent scoop_consumer_tests.test_error_type_in_scoop_context, "test_error_type_in_scoop_context")
			run_test (agent scoop_consumer_tests.test_address_is_generic_compatible, "test_address_is_generic_compatible")
			run_test (agent scoop_consumer_tests.test_client_socket_separate_keyword_compatible, "test_client_socket_separate_keyword_compatible")
			run_test (agent scoop_consumer_tests.test_server_socket_separate_keyword_compatible, "test_server_socket_separate_keyword_compatible")
			run_test (agent scoop_consumer_tests.test_address_void_safe, "test_address_void_safe")
			run_test (agent scoop_consumer_tests.test_error_type_void_safe, "test_error_type_void_safe")
			run_test (agent scoop_consumer_tests.test_client_socket_void_safe, "test_client_socket_void_safe")
		end

	run_scoop_concurrency_tests
			-- Run TEST_SCOOP_CONCURRENCY
		do
			print ("%N=== TEST_SCOOP_CONCURRENCY ===%N")
			run_test (agent scoop_concurrency_tests.test_concurrent_client_socket_type, "test_concurrent_client_socket_type")
			run_test (agent scoop_concurrency_tests.test_concurrent_server_socket_type, "test_concurrent_server_socket_type")
			run_test (agent scoop_concurrency_tests.test_concurrent_address_type, "test_concurrent_address_type")
			run_test (agent scoop_concurrency_tests.test_concurrent_error_type, "test_concurrent_error_type")
			run_test (agent scoop_concurrency_tests.test_separate_object_type_conformance_client, "test_separate_object_type_conformance_client")
			run_test (agent scoop_concurrency_tests.test_separate_object_type_conformance_server, "test_separate_object_type_conformance_server")
			run_test (agent scoop_concurrency_tests.test_separate_object_type_conformance_address, "test_separate_object_type_conformance_address")
			run_test (agent scoop_concurrency_tests.test_separate_object_type_conformance_error, "test_separate_object_type_conformance_error")
			run_test (agent scoop_concurrency_tests.test_client_socket_void_safety_separate, "test_client_socket_void_safety_separate")
			run_test (agent scoop_concurrency_tests.test_server_socket_void_safety_separate, "test_server_socket_void_safety_separate")
			run_test (agent scoop_concurrency_tests.test_address_immutability_separate, "test_address_immutability_separate")
			run_test (agent scoop_concurrency_tests.test_connection_semantics_separate, "test_connection_semantics_separate")
		end

	run_precondition_investigation_tests
			-- Run TEST_PRECONDITION_INVESTIGATION
		do
			print ("%N=== TEST_PRECONDITION_INVESTIGATION ===%N")
			run_test (agent precondition_investigation_tests.test_direct_empty_host_violation, "test_direct_empty_host_violation")
			run_test (agent precondition_investigation_tests.test_direct_port_zero_violation, "test_direct_port_zero_violation")
			run_test (agent precondition_investigation_tests.test_direct_negative_port_violation, "test_direct_negative_port_violation")
			run_test (agent precondition_investigation_tests.test_direct_port_over_65535_violation, "test_direct_port_over_65535_violation")
			run_test (agent precondition_investigation_tests.test_violation_with_status_check, "test_violation_with_status_check")
			run_test (agent precondition_investigation_tests.test_object_state_after_invalid_creation, "test_object_state_after_invalid_creation")
			run_test (agent precondition_investigation_tests.test_invariant_violation_detection, "test_invariant_violation_detection")
			run_test (agent precondition_investigation_tests.test_void_host_precondition, "test_void_host_precondition")
		end

	run_precondition_analysis_tests
			-- Run TEST_PRECONDITION_ANALYSIS
		do
			print ("%N=== TEST_PRECONDITION_ANALYSIS ===%N")
			run_test (agent precondition_analysis_tests.test_what_happens_with_empty_host, "test_what_happens_with_empty_host")
			run_test (agent precondition_analysis_tests.test_what_happens_with_port_zero, "test_what_happens_with_port_zero")
		end

	run_simple_violation_tests
			-- Run TEST_SIMPLE_VIOLATION
		do
			print ("%N=== TEST_SIMPLE_VIOLATION ===%N")
			run_test (agent simple_violation_tests.test_simple_empty_host_direct, "test_simple_empty_host_direct")
		end

feature {NONE} -- Test Suite Instances

	lib_tests: LIB_TESTS
	address_tests: TEST_ADDRESS
	error_type_tests: TEST_ERROR_TYPE
	client_socket_tests: TEST_CLIENT_SOCKET
	server_socket_tests: TEST_SERVER_SOCKET
	scoop_consumer_tests: TEST_SCOOP_CONSUMER
	scoop_concurrency_tests: TEST_SCOOP_CONCURRENCY
	precondition_investigation_tests: TEST_PRECONDITION_INVESTIGATION
	precondition_analysis_tests: TEST_PRECONDITION_ANALYSIS
	simple_violation_tests: TEST_SIMPLE_VIOLATION

feature {NONE} -- Test Count Tracking

	passed: INTEGER
			-- Number of passed tests

	failed: INTEGER
			-- Number of failed tests

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run a single test and update counters.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				a_test.call (Void)
				print ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			print ("  FAIL: " + a_name + "%N")
			failed := failed + 1
			l_retried := True
			retry
		end

end
