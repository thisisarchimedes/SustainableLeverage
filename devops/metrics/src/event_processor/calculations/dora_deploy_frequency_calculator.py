from datetime import datetime, timedelta, date, time
import pandas as pd

class DORADeployFrequencyCalculator():
    def __init__(self):
        pass

    def get_deployment_frequency(self, daily_deploy_volume: pd.DataFrame, start_date: date, end_date: date) -> float:
        """
            daily_deploy_volume: DataFrame with columns 'Day' (date of the day) and 'DeployCount' (integer value of how many deploys we had this day)

            Returns: DeploymentFrequency
            * DeploymentFrequency is a number of deploys per day
        """
       
        weekly_deployment_data = self.get_days_with_deploy_per_week_from_daily_deploy_volume(daily_deploy_volume, start_date, end_date)

        return weekly_deployment_data['DaysWithDeploy'].median()
        
    
    def get_days_with_deploy_per_week_from_daily_deploy_volume(self, daily_deploy_volume: pd.DataFrame, start_date: date, end_date: date) -> pd.DataFrame:
        """
            daily_deploy_volume: DataFrame with columns 'Day' (date of the day) and 'DeployCount' (integer value of how many deploys we had this day)

            Returns: Week|DaysWithDeploy
            * Week is a date of the first Monday of the week
            * DaysWithDeploy is a number of days with at least one deploy during the week
        """

        daily_deploy_volume = self._prepare_daily_volume_data(daily_deploy_volume)
        start_date, end_date = self._adjust_date_range(start_date, end_date)
        date_range = self._create_weekly_date_range(start_date, end_date)
        
        weekly_deploy_count = self._calculate_weekly_deploy_counts(daily_deploy_volume)
        return self._create_output_dataframe(date_range, weekly_deploy_count)


    def _prepare_daily_volume_data(self, daily_deploy_volume: pd.DataFrame) -> pd.DataFrame:
        """Filter out weekends and convert non-zero deploy counts to 1."""

        daily_deploy_volume['Day'] = pd.to_datetime(daily_deploy_volume['Day'])
        is_weekday = daily_deploy_volume['Day'].dt.weekday < 5
        daily_deploy_volume = daily_deploy_volume[is_weekday]
        daily_deploy_volume['DeployCount'] = daily_deploy_volume['DeployCount'].apply(lambda x: 1 if x >= 1 else 0)

        return daily_deploy_volume

    def _adjust_date_range(self, start_date: date, end_date: date) -> tuple:
        """Adjust start and end dates to the nearest Monday and Sunday, respectively."""

        start_date = self._adjust_to_previous_monday(start_date)
        end_date = self._adjust_to_following_sunday(end_date)

        return start_date, end_date

    def _adjust_to_previous_monday(self, some_date: date) -> datetime:
        """Adjust a date to the previous Monday."""

        return datetime.combine(some_date, time.min) - timedelta(days=some_date.weekday())

    def _adjust_to_following_sunday(self, some_date: date) -> datetime:
        """Adjust a date to the following Sunday."""

        adjustment = timedelta(days=6 - some_date.weekday()) 
        return datetime.combine(some_date, time.min) + adjustment

    def _create_weekly_date_range(self, start_date: date, end_date: date) -> pd.DatetimeIndex:
        """Create a weekly date range starting from Monday."""

        return pd.date_range(start=start_date, end=end_date, freq='W-MON')

    def _calculate_weekly_deploy_counts(self, daily_deploy_volume: pd.DataFrame) -> pd.Series:
        """Calculate the sum of deployment counts for each week."""

        daily_deploy_volume['WeekStart'] = daily_deploy_volume['Day'].apply(lambda x: x - timedelta(days=x.weekday()))
        return daily_deploy_volume.groupby('WeekStart')['DeployCount'].sum()

    def _create_output_dataframe(self, date_range, weekly_deploy_counts: pd.Series) -> pd.DataFrame:
        """Create the output DataFrame with weeks and deployment counts."""

        output = pd.DataFrame({'Week': date_range})
        output['DaysWithDeploy'] = output['Week'].apply(lambda d: weekly_deploy_counts.get(d, 0))
        return output