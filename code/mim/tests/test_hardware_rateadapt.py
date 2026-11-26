"""Offline measurement guards; no hardware success is inferred from these."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('rate_test', Path(__file__).with_name('run_hardware_rateadapt.py'))
rate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rate)


class MeasurementTests(unittest.TestCase):
    def test_real_change_passes(self):
        self.assertTrue(rate.compare({'videoKbps':[6000]*3}, {'videoKbps':[5900,2000,6100]})['pass'])

    def test_accepted_command_without_change_fails(self):
        self.assertFalse(rate.compare({'videoKbps':[6000]*3}, {'videoKbps':[6000]*3})['pass'])

    def test_quiet_scene_false_positive_fails(self):
        self.assertFalse(rate.compare({'videoKbps':[6000,2000,6000]}, {'videoKbps':[6000,2000,6000]})['pass'])

    def test_no_recovery_fails(self):
        self.assertFalse(rate.compare({'videoKbps':[6000]*3}, {'videoKbps':[6000,2000,2000]})['pass'])

    def test_complete_packets_and_rate(self):
        packets = [{'pts_time':str(i/60), 'dts_time':str(i/60), 'size':'12500'} for i in range(3600)]
        result = rate.packet_metrics(packets)
        self.assertEqual(result['videoKbps'], [6000]*3)
        self.assertEqual(result['durationSeconds'], 60)

    def test_missing_frame_fails(self):
        packets = [{'pts_time':str(i/60), 'dts_time':str(i/60), 'size':'12500'} for i in range(3600) if not 800<=i<804]
        with self.assertRaises(AssertionError):
            rate.packet_metrics(packets)

    def test_nonfinite_clock_fails(self):
        with self.assertRaises(AssertionError):
            rate.packet_metrics([{'pts_time':'nan', 'dts_time':'0', 'size':'100'}])

    def test_presentation_reset_fails(self):
        packets = [{'pts_time':str(i/60), 'dts_time':str(i/60), 'size':'12500'} for i in range(3600)]
        packets[1000]['pts_time'] = '0'
        with self.assertRaises(AssertionError):
            rate.packet_metrics(packets)


if __name__ == '__main__':
    unittest.main()
