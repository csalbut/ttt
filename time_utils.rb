module TimeUtilities

    def human_readable(seconds)
        days = seconds / (3600 * 8)
        seconds = seconds % (3600 * 8)
        hours = seconds / 3600
        seconds = seconds % 3600
        minutes = seconds / 60
        seconds = seconds % 60

        if hours != 0
            hours_s = hours.to_s + "h "
        else
            hours_s = ""
        end

        if days != 0
            days_s = days.to_s + "d "
        else
            days_s = ""
        end

        if minutes != 0
            minutes_s = minutes.to_s + "m "
        else
            minutes_s = ""
        end

        if seconds != 0
            seconds_s = seconds.to_s + "s "
        else
            seconds_s = ""
        end

        return days_s + hours_s + minutes_s + seconds_s
    end

end

