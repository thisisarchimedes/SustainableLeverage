import pytest
import datetime as dt
import pandas as pd

from src.event_processor.calculations.dora_deploy_frequency_calculator import DORADeployFrequencyCalculator

class TestDORADeployFrequencyCalculator:

    def setup_method(self) -> None:
        
        self.test_df = pd.DataFrame({
            'Day': [
                '2023-12-12',
                '2023-12-18', '2023-12-19',
                '2023-12-25', '2023-12-27',
                '2024-01-01', '2024-01-02', '2024-01-03', '2024-01-04'
            ],
            'DeployCount': [1,
                            2, 2,
                            1, 2,
                            1, 1, 1, 3]}
        )


    def test_calculate_days_with_deploy_per_week(self):

        start_date = dt.date(2023, 12, 1)
        end_date = dt.date(2024, 2, 3)

        deploy_freq_calc = DORADeployFrequencyCalculator()
        res = deploy_freq_calc.get_days_with_deploy_per_week_from_daily_deploy_volume(daily_deploy_volume=self.test_df,
                                                                                      start_date=start_date,
                                                                                      end_date=end_date)

        # We expect DataFrame with two columns: 'Week' and 'DaysWithDeploy'.
        # 'Week' should be 1,2,3,4
        # 'DaysWithDeploy' should be 1,2,2,4
        assert isinstance(res, pd.DataFrame)
        assert 'Week' in res.columns
        assert 'DaysWithDeploy' in res.columns

        assert res.iloc[0]['Week'] == dt.datetime(2023, 11, 27)
        assert res.iloc[0]['DaysWithDeploy'] == 0

        assert res.iloc[1]['Week'] == dt.datetime(2023, 12, 4)
        assert res.iloc[1]['DaysWithDeploy'] == 0

        assert res.iloc[2]['Week'] == dt.datetime(2023, 12, 11)
        assert res.iloc[2]['DaysWithDeploy'] == 1

        assert res.iloc[3]['Week'] == dt.datetime(2023, 12, 18)
        assert res.iloc[3]['DaysWithDeploy'] == 2

        assert res.iloc[4]['Week'] == dt.datetime(2023, 12, 25)
        assert res.iloc[4]['DaysWithDeploy'] == 2

        assert res.iloc[5]['Week'] == dt.datetime(2024, 1, 1)
        assert res.iloc[5]['DaysWithDeploy'] == 4

        assert res.iloc[6]['Week'] == dt.datetime(2024, 1, 8)
        assert res.iloc[6]['DaysWithDeploy'] == 0

        assert res.iloc[7]['Week'] == dt.datetime(2024, 1, 15)
        assert res.iloc[7]['DaysWithDeploy'] == 0

        assert res.iloc[8]['Week'] == dt.datetime(2024, 1, 22)
        assert res.iloc[8]['DaysWithDeploy'] == 0

        assert res.iloc[9]['Week'] == dt.datetime(2024, 1, 29)
        assert res.iloc[9]['DaysWithDeploy'] == 0

        assert len(res) == 10


    def test_deploy_frequency_zero(self):

        start_date = dt.date(2023, 12, 1)
        end_date = dt.date(2024, 2, 3)

        deploy_freq_calc = DORADeployFrequencyCalculator()
        res = deploy_freq_calc.get_deployment_frequency(daily_deploy_volume=self.test_df,
                                                            start_date=start_date,
                                                            end_date=end_date)
        
        # Test data DaysWithDeploy: 0, 0, 1, 2, 2, 4, 0, 0, 0, 0
        # 0, 0, 0, 0, 0, 0, 1, 2, 2, 4
        # Deploy frequency should be 0
        assert res == 0

    
    def test_deploy_frequency_two(self):

        start_date = dt.date(2023, 12, 12)
        end_date = dt.date(2024, 1, 4)

        deploy_freq_calc = DORADeployFrequencyCalculator()
        res = deploy_freq_calc.get_deployment_frequency(daily_deploy_volume=self.test_df,
                                                            start_date=start_date,
                                                            end_date=end_date)
        
        # Test data DaysWithDeploy: 0, 0, 1, 2, 2, 4, 0, 0, 0, 0
        # 0, 0, 0, 0, 0, 0, 1, 2, 2, 4
        # Deploy frequency should be 0
        assert res == 2
